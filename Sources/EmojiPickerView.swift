import SwiftUI

struct EmojiPickerView: View {
    @ObservedObject var state: AppState
    
    var body: some View {
        let columns = Array(repeating: GridItem(.fixed(36), spacing: 4), count: state.columnsCount)
        
        VStack(spacing: 8) {
            // Search Bar Area
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                Text(state.searchQuery.isEmpty ? "Search..." : state.searchQuery)
                    // If selected, turn text white, else normal colors
                    .foregroundColor(state.searchQuery.isEmpty ? .secondary : (state.isSearchSelected ? .white : .primary))
                    .font(.system(size: 14, weight: .medium))
                    // Add tiny padding and blue background to mimic standard macOS text selection
                    .padding(.horizontal, state.isSearchSelected ? 4 : 0)
                    .padding(.vertical, state.isSearchSelected ? 2 : 0)
                    .background(state.isSearchSelected ? Color.accentColor : Color.clear)
                    .cornerRadius(4)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            
            Divider()
            
            // Emoji Grid Area
            if state.filteredEmojis.isEmpty {
                Text("No emojis found 👻")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14))
                    .padding()
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    ScrollViewReader { proxy in
                        LazyVGrid(columns: columns, spacing: 4) {
                            ForEach(0..<state.filteredEmojis.count, id: \.self) { index in
                                Text(state.filteredEmojis[index].symbol)
                                    .font(.system(size: 20))
                                    .frame(width: 36, height: 36)
                                    .background(index == state.selectedIndex ? Color.accentColor : Color.clear)
                                    .cornerRadius(8)
                                    // Give each item an ID so ScrollViewReader can find it
                                    .id(index)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 12)
                        // This will finally work because SwiftUI state is actually preserved!
                        .onChange(of: state.selectedIndex) { newIndex in
                            // Adding a tiny animation makes it glide like a text cursor
                            withAnimation(.easeInOut(duration: 0.1)) {
                                proxy.scrollTo(newIndex, anchor: nil)
                            }
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .frame(width: 280, height: 270, alignment: .top)
        .background(VisualEffectView(material: .popover, blendingMode: .behindWindow))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
}

// Helper wrapper to bring AppKit's native blur into SwiftUI
struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
