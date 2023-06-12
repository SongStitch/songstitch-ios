import SwiftUI
import UIKit
import Combine


// Fullscreen image view logic
struct FullscreenImageView: View {
    @Binding var isPresented: Bool
    let image: UIImage

    @GestureState private var scale: CGFloat = 1.0
    @State private var isZoomed = false
    @State private var lastScaleValue: CGFloat = 1.0

    @State private var offset: CGSize = .zero
    @GestureState private var dragOffset: CGSize = .zero

    var body: some View {
        ZStack {
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.primary)
                            .font(.title)
                            .padding()
                    }
                }
                Spacer()

                let magnificationGesture = MagnificationGesture()
                    .updating($scale) { value, scale, _ in
                        let scaledValue = value.magnitude
                        scale = min(max(scaledValue, 1.0), 10.0)
                    }
                    .onEnded { value in
                        lastScaleValue = min(max(value, 1.0), 10.0)
                        isZoomed = value > 1.0
                    }
                

                let dragGesture = DragGesture()
                    .updating($dragOffset) { value, state, _ in
                        state = value.translation
                    }
                    .onEnded { value in
                        offset.width += value.translation.width
                        offset.height += value.translation.height
                    }

                let tapGesture = TapGesture(count: 2)
                    .onEnded {
                        isZoomed.toggle()
                        if !isZoomed {
                            offset = .zero
                            lastScaleValue = 1.0
                        }
                    }

                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: isZoomed ? .fill : .fit)
                    .scaleEffect(scale)
                    .offset(x: isZoomed ? (offset.width + dragOffset.width) : 0, y: isZoomed ? (offset.height + dragOffset.height) : 0)
                    .gesture(magnificationGesture.simultaneously(with: dragGesture))
                    .gesture(tapGesture)
                    .padding()

                Spacer()
            }
        }
        .statusBar(hidden: true)
    }
}


class ImageLoader: ObservableObject {
    @Published var image: UIImage? = nil
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var error: IdentifiableError? = nil
    @Published var errorHasOccurred: Bool = false

    
    
    func loadImage(username: String,
                   method: String,
                   period: String,
                   track: Bool,
                   artist: Bool,
                   album: Bool,
                   playcount: Bool,
                   rows: Int,
                   columns: Int,
                   fontsize: Int) {
        
        self.errorHasOccurred = false
        var components = URLComponents()
        components.scheme = "https"
        components.host = "songstitch.art"
        components.path = "/collage"
        components.queryItems = [
            URLQueryItem(name: "username", value: username),
            URLQueryItem(name: "method", value: method),
            URLQueryItem(name: "period", value: period),
            URLQueryItem(name: "track", value: String(track)),
            URLQueryItem(name: "artist", value: String(artist)),
            URLQueryItem(name: "album", value: String(album)),
            URLQueryItem(name: "playcount", value: String(playcount)),
            URLQueryItem(name: "rows", value: String(rows)),
            URLQueryItem(name: "columns", value: String(columns)),
            URLQueryItem(name: "fontsize", value: String(fontsize)),
        ]
        
        guard let url = components.url else { return }
        
        isLoading = true
        errorMessage = nil
        URLSession.shared.dataTask(with: url) { (data, response, error) in
            DispatchQueue.main.async {
                self.isLoading = false
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    self.errorHasOccurred = true
                } else if let httpResponse = response as? HTTPURLResponse,
                          httpResponse.statusCode != 200,
                          let responseData = data,
                          let errorMessage = String(data: responseData, encoding: .utf8) {
                          self.errorHasOccurred = true
                    self.errorMessage = "Error: \(errorMessage)"
                } else if let data = data, let image = UIImage(data: data) {
                    self.image = image
                }
            }
        }.resume()
    }
}

class SaveToPhotosActivity: UIActivity {
    override var activityTitle: String? {
        return "Save to Photos"
    }
    
    override var activityImage: UIImage? {
        return UIImage(systemName: "square.and.arrow.down")
    }
    
    override class var activityCategory: UIActivity.Category {
        return .action
    }
    
    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        for item in activityItems {
            if item is UIImage {
                return true
            }
        }
        return false
    }
    
    override func prepare(withActivityItems activityItems: [Any]) {
        for item in activityItems {
            if let image = item as? UIImage {
                UIImageWriteToSavedPhotosAlbum(image, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
            }
        }
    }
    
    override func perform() {
        activityDidFinish(true)
    }
    
    @objc func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        // Handle save completion
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<ShareSheet>) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: [SaveToPhotosActivity()])
        controller.excludedActivityTypes = [.addToReadingList, .openInIBooks] // Optional: Exclude specific activity types
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: UIViewControllerRepresentableContext<ShareSheet>) {
        // No update needed
    }
}


struct ContentView: View {
    @State var username: String
    @State var method: String = "album"
    @State var period: String = "7day"
    @State var track: Bool = true
    @State var artist: Bool = true
    @State var album: Bool = true
    @State var playcount: Bool = true
    @State var rows: Int = 3
    @State var columns: Int = 3
    @State var fontsize: Int = 12
    @State var generateStatus: Bool = false
    @StateObject private var imageLoader = ImageLoader()
    @State private var isShowingShareSheet = false
    @State private var isShowingFullscreenImage = false
    @Environment(\.presentationMode) var presentationMode
    @FocusState var isInputActive: Bool
    @State private var isShowingImage: Bool = false
    @State private var isShowingError = true
    @State private var IsShowingGenerate = true

    func triggerGenerateButton() {
        imageLoader.loadImage(username: username,
                              method: method,
                              period: period,
                              track: track,
                              artist: artist,
                              album: album,
                              playcount: playcount,
                              rows: rows,
                              columns: columns,
                              fontsize: fontsize
        )
        isShowingImage = imageLoader.errorMessage == nil
    }

    
    init() {
        _username = State(initialValue: UserDefaults.standard.string(forKey: "Username") ?? "")
        //UISplitViewController.appearance().preferredDisplayMode = twoOverSecondary
        
        UISplitViewController().preferredDisplayMode = .twoDisplaceSecondary
        //UINavigationController().viewControllers = UINavigationController()
        
        
        if UITraitCollection.current.userInterfaceStyle == .dark {
            UITextField.appearance().tintColor = UIColor.white
            UITextView.appearance().tintColor = UIColor.white
            UINavigationBar.appearance().tintColor = UIColor.white
        } else {
            UITextField.appearance().tintColor = UIColor.black
            UITextView.appearance().tintColor = UIColor.black
            UINavigationBar.appearance().tintColor = UIColor.black
        }
        
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                if !isShowingImage {
                    VStack {
                        /*       Image("logo")
                         .resizable()
                         .aspectRatio(contentMode: .fit)
                         .padding(.top, 10)
                         .padding(.bottom, -10)*/
                        Form {
                            Section(header: Text("Generate Your Last.FM Collage")
                                .frame(maxWidth: .infinity) // Extend the header to full width
                                .font(.headline)
                                .padding(.vertical, 0) // Add vertical padding to center the text
                            //    .background(Color.gray.opacity(0.2)) // Optional: add a background color
                            ){                                    VStack {
                                        Text("Select a Collage Type")
                                            .font(.headline)
                                        Picker(selection: $method, label: Text("Collage")) {
                                            Text("Top Albums").tag("album")
                                            Text("Top Artists").tag("artist")
                                            Text("Top Tracks").tag("track")
                                        }
                                        .pickerStyle(SegmentedPickerStyle())
                                        .accentColor(.blue)
                                        
                                    }.padding(.bottom, -10)
                                    .padding(.top, 10)
                            
                                VStack {
                                /*    Text("Required Options")
                                        .font(.headline)
                                        .padding(.bottom, 10)
                                        .padding(.top, 10) */
                                    Text("Your Last.fm Username")
                                        .font(.headline)
                                        .padding(.top, 20)
                                    TextField("Last.FM Username", text: $username, onEditingChanged: { _ in
                                    })  .focused($isInputActive)
                                        .textFieldStyle(RoundedBorderTextFieldStyle()) // Add rounded borders
                                        .padding(.horizontal, 20)
                                        .font(.title3)
                                        .padding(.bottom, 10)

                                    
                                        .toolbar {
                                            ToolbarItemGroup(placement: .keyboard) {
                                                Button("Generate") {
                                                    triggerGenerateButton()
                                                }.foregroundColor(Color.blue)

                                                Spacer()

                                                .foregroundColor(Color.blue)
                                                Button("Done") {
                                                    isInputActive = false
                                                }
                                                .foregroundColor(Color.blue)
                                            }
                                        }
                              
                                    Group {
                                        
                                        Text("Collage Options")
                                            .font(.headline)
                                            .padding(.bottom, 10)
                                            .padding(.top, 10)
                                        
                                        HStack {
                                            Text("Period")
                                            Spacer()
                                            Picker("", selection: $period) {
                                                Text("7 Days").tag("7day")
                                                Text("1 Month").tag("1month")
                                                Text("3 Months").tag("3month")
                                                Text("6 Months").tag("6month")
                                                Text("12 Months").tag("12month")
                                                Text("Overall").tag("overall")
                                            }
                                            .pickerStyle(MenuPickerStyle())
                                            .accentColor(.blue)
                                            .padding(.bottom, 10)
                                        }
                                        
                                        if method != "artist" {
                                            Toggle(isOn: $album) {
                                                Text("Display Album Name")
                                            }
                                        }
                                        if method == "track" {
                                            Toggle(isOn: $track) {
                                                Text("Display Track Name")
                                            }
                                        }
                                        Toggle(isOn: $artist) {
                                            Text("Display Artist Name")
                                        }
                                        Toggle(isOn: $playcount) {
                                            Text("Display Play Count")
                                        }
                                        .padding(.bottom, 10)
                                        
                                        VStack {
                                            Stepper(value: $rows, in: (method == "album" ? 1...15 : (method == "track"  ? 1...5 : 1...10))) {
                                                
                                                Text("Rows: \(rows)")
                                            }
                                            Stepper(value: $columns, in: (method == "album" ? 1...15 : (method == "track"  ? 1...5 : 1...10))) {
                                                
                                                Text("Columns: \(columns)")
                                            }
                                        } .padding(.top, 10)
                                        
                                        
                                        HStack {
                                            VStack {
                                                Text("Text Font Size")
                                                Picker("Font Size", selection: $fontsize) {
                                                    Text("Small").tag(12)
                                                    Text("Medium").tag(16)
                                                    Text("Large").tag(20)
                                                }
                                                .pickerStyle(SegmentedPickerStyle())
                                            }.padding(.top, 10)
                                                .padding(.bottom, 20)
                                            
                                        }
                                    }
                                    VStack {
                                    if let errorMessage = imageLoader.errorMessage {
                                        if isShowingError {
                                            Text(errorMessage)
                                                .foregroundColor(.red)
                                        }        else {
                                            Text("") // Empty text to reserve space
                                        }
                                        
                                    }
                            }
                                }
         
                            }
                    
                        }
                    }
                    .padding(.top, 0)
                    .padding(.bottom, -1)
                }
                VStack {
                    /*    if imageLoader.image != nil {
                     Divider()
                     .frame(height: 1)
                     .padding(.horizontal)
                     .padding(.top, -1)
                     }*/
                    if let image = imageLoader.image, isShowingImage, imageLoader.errorMessage == nil {
                        Button(action: {
                            withAnimation {
                                isShowingFullscreenImage = true
                            }
                        })
                        {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                //.frame(maxWidth: .infinity, maxHeight: .infinity)
                                .frame(maxWidth: UIScreen.main.bounds.width * 0.95, maxHeight: .infinity)
                                .clipShape(Rectangle())
                                .padding(.top, 20)
                                .padding(.bottom, 20)
                        }
                        .transition(.move(edge: .top)) // Add slide up transition
                       .fullScreenCover(isPresented: $isShowingFullscreenImage) {
                            FullscreenImageView(isPresented: $isShowingFullscreenImage, image: image)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .onTapGesture {
                            presentationMode.wrappedValue.dismiss()
                        }
                        withAnimation {
                            Text("Tap the Image to view in fullscreen")
                                .opacity(isShowingFullscreenImage ? 0 : 1) // Start with opacity 0 if fullscreen image is showing
                                .padding(.bottom, 10)
                        }
                    HStack {
                            Button(action: {
                                withAnimation {
                                    isShowingShareSheet = true
                                }
                            }) {
                                Label("Share", systemImage: "square.and.arrow.up")
                                    .padding()
                                    .foregroundColor(.blue)
                                    .background(
                                        Capsule()
                                            .stroke(Color.blue, lineWidth: 1)                                        )
                            }
                            .sheet(isPresented: $isShowingShareSheet) {
                                ShareSheet(activityItems: [image])
                            }
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    imageLoader.image = nil
                                }
                                withAnimation {
                                    isShowingImage = false
                                }
                            }) {
                                Label("Close", systemImage: "xmark")
                                    .padding()
                                    .foregroundColor(.red)
                                    .background(
                                        Capsule()
                                     .stroke(Color.red, lineWidth: 1)                                        )
                            }.padding(.leading, 10)
                        }//.transition(.move(edge: .bottom))
//                        .animation(.spring(), value: isShowingImage)

                        
                    }
                    Spacer()

                    Color.clear
                        .frame(width: 20, height: 20) // Modify as per your needs
                        .overlay(
                            Group {
                                if imageLoader.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                        .padding(.top, 20)
                                        .padding(.bottom, 0)
                                }
                            }
                        )

                    
                    Button(action: {
                        imageLoader.loadImage(username: username,
                                              method: method,
                                              period: period,
                                              track: track,
                                              artist: artist,
                                              album: album,
                                              playcount: playcount,
                                              rows: rows,
                                              columns: columns,
                                              fontsize: fontsize
                        )
                            isShowingImage = imageLoader.errorMessage == nil
                    }
) {
                        Text(imageLoader.isLoading ? "Generating..." : "Generate")
                            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 50)
                            .edgesIgnoringSafeArea(.bottom)
                            .font(.headline)
                            .foregroundColor(.white)
                            .background(imageLoader.isLoading ? Color.gray : Color.blue)
                            .cornerRadius(15)
                            .padding(.horizontal)
                            .padding(.top, 10)
                            .padding(.bottom, 10)
                            .zIndex(-1)
                            .opacity(imageLoader.isLoading || generateStatus ? 0.5 : 1)
                    }
                    .disabled(generateStatus || imageLoader.isLoading || isShowingImage)
                    .opacity((generateStatus || imageLoader.isLoading || isShowingImage || !IsShowingGenerate) ? 0 : 1)
                    .alert(item: $imageLoader.error) { error in
                        Alert(
                            title: Text("Error"),
                            message: Text(error.error.localizedDescription),
                            dismissButton: .default(Text("OK"))
                        )
                    }
                }
            }
        }
        .onDisappear {
            UserDefaults.standard.set(username, forKey: "Username")
        }
        .alert(item: $imageLoader.error) { error in
            Alert(
                title: Text("Error"),
                message: Text(error.error.localizedDescription),
                dismissButton: .default(Text("OK"))
            )
        }
        .onChange(of: imageLoader.errorHasOccurred) { newValue in
            // This will be called every time imageLoader.errorHasOccurred changes
            if !newValue {
                // if there's no error, show the image
                    isShowingError = false
                isShowingImage = imageLoader.image != nil
            } else {
                // if there's an error, hide the image
                //withAnimation(.easeIn(duration: 0.5)) {
                    isShowingError = true
                //}
                isShowingImage = false
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationViewStyle(StackNavigationViewStyle())
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isShowingError = false
            IsShowingGenerate = false
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isShowingError = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                IsShowingGenerate = true
            }
        }.statusBar(hidden: false)
        
    }
}

struct IdentifiableError: Identifiable {
    let id = UUID()
    let error: Error
}

