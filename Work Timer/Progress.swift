//
//  Progress.swift
//  Work Timer
//
//  Created by Alexey Duryagin on 04/12/2022.
//

import SwiftUI

struct LongLine: View {
    var color: Color = Color.gray
    
    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: 1, height: 18, alignment: .center)
    }
}

struct ShortLine: View {
    var color: Color = Color.gray
    
    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: 1, height: 14, alignment: .center)
    }
}

struct Progress: View {
    var value: Double
    var total: Double
    
    var body: some View {
        ZStack {
            ProgressView(value: value, total: total).zIndex(1)
            HStack {
                ShortLine()
                Spacer()
                ForEach((1...15), id: \.self) {_ in
                    ShortLine(color: Color.gray.opacity(0.5))
                    Spacer()
                }
                ShortLine()
            }
            HStack {
                LongLine()
                Spacer()
                LongLine(color: Color.orange)
                Spacer()
                LongLine(color: Color.orange)
                Spacer()
                LongLine(color: Color.orange)
                Spacer()
                LongLine()
            }
        }
    }
}

struct Progress_Previews: PreviewProvider {
    static var previews: some View {
        Progress(value: 5, total: 10).padding().frame(width: 200)
    }
}
