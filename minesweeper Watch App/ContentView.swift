import SwiftUI
import WatchKit

struct ContentView: View {
    @State private var grid = Array(repeating: Array(repeating: Cell(), count: 8), count: 8)
    @State private var gameOver = false
    @State private var gameWon = false
    @State private var scale: CGFloat = 0.8
    @State private var isFirstClick = true
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView([.horizontal, .vertical]) {
                gameBoard(geometry: geometry)
                    .frame(width: geometry.size.width * max(scale, 1), height: geometry.size.width * max(scale, 1))
            }
        }
        .ignoresSafeArea()
        .focusable()
        .digitalCrownRotation($scale, from: 0.8, through: 2.0, by: 0.1, sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
        .onAppear(perform: onAppearSetup)
        .alert(isPresented: Binding<Bool>(
            get: { gameOver || gameWon },
            set: { _ in }
        )) {
            gameAlert
        }
    }
    
    private func gameBoard(geometry: GeometryProxy) -> some View {
        VStack(spacing: 1) {
            ForEach(0..<8, id: \.self) { row in
                HStack(spacing: 1) {
                    ForEach(0..<8, id: \.self) { column in
                        cellView(row: row, column: column, geometry: geometry)
                    }
                }
            }
        }
        .background(Color.black)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray, lineWidth: 2)
        )
    }
    
    private func cellView(row: Int, column: Int, geometry: GeometryProxy) -> some View {
        CellView(cell: $grid[row][column])
            .frame(width: geometry.size.width * scale / 8, height: geometry.size.width * scale / 8)
            .onTapGesture {
                handleCellTap(row: row, column: column)
            }
            .onLongPressGesture {
                toggleFlag(row: row, column: column)
            }
    }
    
    private var gameAlert: Alert {
        Alert(
            title: Text(gameOver ? "Game Over" : "Congratulations!"),
            message: Text(gameOver ? "You hit a mine!" : "You won!"),
            dismissButton: .default(Text("New Game"), action: initializeGrid)
        )
    }
    
    private func onAppearSetup() {
        initializeGrid()
        WKExtension.shared().isAutorotating = true
        WKApplication.shared().isAutorotating = false
    }
    
    private func restoreWatchFace() {
        WKApplication.shared().isAutorotating = true
    }
    
    private func handleCellTap(row: Int, column: Int) {
        if isFirstClick {
            setupGame(safeRow: row, safeColumn: column)
            isFirstClick = false
        }
        revealCell(row: row, column: column)
    }
    
    func initializeGrid() {
        grid = Array(repeating: Array(repeating: Cell(), count: 8), count: 8)
        gameOver = false
        gameWon = false
        isFirstClick = true
        restoreWatchFace()
    }
    
    func setupGame(safeRow: Int, safeColumn: Int) {
        var minesPlaced = 0
        while minesPlaced < 10 {
            let row = Int.random(in: 0..<8)
            let col = Int.random(in: 0..<8)
            if !grid[row][col].isMine && !(row == safeRow && col == safeColumn) {
                grid[row][col].isMine = true
                minesPlaced += 1
            }
        }
        
        for row in 0..<8 {
            for col in 0..<8 {
                grid[row][col].adjacentMines = countAdjacentMines(row: row, column: col)
            }
        }
    }
    
    func countAdjacentMines(row: Int, column: Int) -> Int {
        var count = 0
        for i in -1...1 {
            for j in -1...1 {
                let newRow = row + i
                let newCol = column + j
                if newRow >= 0 && newRow < 8 && newCol >= 0 && newCol < 8 && grid[newRow][newCol].isMine {
                    count += 1
                }
            }
        }
        return count
    }
    
    func revealCell(row: Int, column: Int) {
        guard !grid[row][column].isRevealed && !grid[row][column].isFlagged && !gameOver && !gameWon else { return }
        
        grid[row][column].isRevealed = true
        
        if grid[row][column].isMine {
            gameOver = true
            WKInterfaceDevice.current().play(.failure)
            restoreWatchFace()
        } else {
            WKInterfaceDevice.current().play(.click)
            if grid[row][column].adjacentMines == 0 {
                for i in -1...1 {
                    for j in -1...1 {
                        let newRow = row + i
                        let newCol = column + j
                        if newRow >= 0 && newRow < 8 && newCol >= 0 && newCol < 8 {
                            revealCell(row: newRow, column: newCol)
                        }
                    }
                }
            }
        }
        
        checkWinCondition()
    }
    
    func toggleFlag(row: Int, column: Int) {
        guard !grid[row][column].isRevealed && !gameOver && !gameWon else { return }
        grid[row][column].isFlagged.toggle()
        WKInterfaceDevice.current().play(.click)
    }
    
    func checkWinCondition() {
        let allCellsRevealed = grid.flatMap { $0 }.filter { !$0.isMine }.allSatisfy { $0.isRevealed }
        if allCellsRevealed {
            gameWon = true
            WKInterfaceDevice.current().play(.success)
            restoreWatchFace()
        }
    }
}

struct Cell {
    var isMine = false
    var isRevealed = false
    var isFlagged = false
    var adjacentMines = 0
}

struct CellView: View {
    @Binding var cell: Cell
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(cell.isRevealed ? Color.white : Color.gray)
            
            if cell.isFlagged && !cell.isRevealed {
                Image(systemName: "flag.fill")
                    .foregroundColor(.red)
            } else if cell.isRevealed {
                if cell.isMine {
                    Image(systemName: "xmark")
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                } else if cell.adjacentMines > 0 {
                    Text("\(cell.adjacentMines)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(numberColor(for: cell.adjacentMines))
                }
            }
        }
    }
    
    private func numberColor(for count: Int) -> Color {
        switch count {
        case 1: return .blue
        case 2: return .green
        case 3: return .red
        case 4: return .purple
        case 5: return .orange
        case 6: return .pink
        case 7: return .gray
        case 8: return .black
        default: return .blue
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
