import SwiftUI
import UIKit
import Combine


struct FullscreenImageView: View {
    @Binding var isPresented: Bool
    let image: UIImage
    
    @GestureState private var scale: CGFloat = 1.0
    @GestureState private var translation: CGSize = .zero
    @State private var isZoomed = false
    
    
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                            .font(.title)
                            .padding()
                    }
                }
                Spacer()
                
                let magnificationGesture = MagnificationGesture()
                    .updating($scale) { value, scale, _ in
                        scale = value.magnitude
                    }
                    .onEnded { value in
                        if value > 1.0 {
                            isZoomed = true
                        }
                    }
                
                let dragGesture = DragGesture()
                    .updating($translation) { value, state, _ in
                        state = value.translation
                    }
                    .onEnded { value in
                        if value.translation.height > 200 {
                            isPresented = false
                        }
                    }
                
                let tapGesture = TapGesture(count: 2)
                    .onEnded {
                        isZoomed.toggle()
                    }
                
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: isZoomed ? .fill : .fit)
                    .scaleEffect(scale)
                    .offset(translation)
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
                } else if let httpResponse = response as? HTTPURLResponse,
                          httpResponse.statusCode != 200,
                          let responseData = data,
                          let errorMessage = String(data: responseData, encoding: .utf8) {
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
    @State var track: Bool = false
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
    @State private var isUsernameValid = true
    
    
    init() {
        _username = State(initialValue: UserDefaults.standard.string(forKey: "Username") ?? "")
        
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
    
    var isUsernameValidBinding: Binding<Bool> {
        Binding<Bool>(
            get: { isUsernameValid },
            set: {
                isUsernameValid = $0
                if !$0 {
                    isInputActive = true // Keep the focus on the text field when an error occurs
                }
            }
        )
    }
    
    func validateUsername() {
        let usernamePredicate = NSPredicate(format: "SELF MATCHES %@", "^[a-zA-Z][a-zA-Z0-9_-]{1,14}$")
        isUsernameValid = usernamePredicate.evaluate(with: username)
    }
    
    var body: some View {
        NavigationView {
            VStack {
                /*       Image("logo")
                 .resizable()
                 .aspectRatio(contentMode: .fit)
                 .padding(.top, 10)
                 .padding(.bottom, -10)*/
                Form {
                    Section(header: Text("Generate Your Last.FM Collage")) {
                        HStack {
                            Picker("Collage", selection: $method) {
                                Text("Top Albums").tag("album")
                                Text("Top Artists").tag("artist")
                                Text("Top Tracks").tag("track")
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .accentColor(.blue)
                            Spacer()
                        }
                        
                        TextField("Last.FM Username", text: $username, onEditingChanged: { _ in
                            validateUsername()
                        })                                         .focused($isInputActive)
                            .alert(isPresented: Binding<Bool>(
                                get: { !isUsernameValid },
                                set: { _ in }
                            )) {
                                Alert(
                                    title: Text("Invalid Username"),
                                    message: Text("Please enter a valid username."),
                                    dismissButton: .default(Text("OK"))
                                )
                            }
                            .toolbar {
                                ToolbarItemGroup(placement: .keyboard) {
                                    Spacer()
                                    Button("Done") {
                                        isInputActive = false
                                    }
                                    .foregroundColor(Color.blue)
                                }
                            }
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
                        }
                        Toggle(isOn: $album) {
                            Text("Display Album Name")
                        }
                        Toggle(isOn: $artist) {
                            Text("Display Artist Name")
                        }
                        Toggle(isOn: $playcount) {
                            Text("Display Play Count")
                        }
                        Stepper(value: $rows, in: 1...10) {
                            Text("Rows: \(rows)")
                        }
                        Stepper(value: $columns, in: 1...10) {
                            Text("Columns: \(columns)")
                        }
                        HStack {
                            Text("Font Size")
                            Picker("Font Size", selection: $fontsize) {
                                Text("Small").tag(12)
                                Text("Medium").tag(16)
                                Text("Large").tag(20)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                        }
                    }
                }
                .padding(.top, 0)
                .padding(.bottom, -1)
                if imageLoader.image != nil {
                    
                    Divider()
                        .frame(height: 1)
                        .padding(.horizontal)
                        .padding(.top, -1)
                }
                if let errorMessage = imageLoader.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                }
                if let image = imageLoader.image {
                    Button(action: {
                        isShowingFullscreenImage = true
                    }) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .padding(.top, 10)
                            .padding(.bottom, 20)
                    }
                    .fullScreenCover(isPresented: $isShowingFullscreenImage) {
                        FullscreenImageView(isPresented: $isShowingFullscreenImage, image: image)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .onTapGesture {
                        presentationMode.wrappedValue.dismiss()
                    }
                    HStack {
                        Button(action: {
                            isShowingShareSheet = true
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
                            imageLoader.image = nil
                        }) {
                            Label("Close", systemImage: "xmark")
                                .padding()
                                .foregroundColor(.red)
                                .background(
                                    Capsule()
                                        .stroke(Color.red, lineWidth: 1)                                        )
                        }
                    }
                }
                
                if imageLoader.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .padding()
                }
                Spacer(minLength: 0)
                Button(action: {
                    validateUsername() // Validate the username before generating
                    if isUsernameValid {
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
                    }
                }) {
                    Text(imageLoader.isLoading ? "Generating..." : "Generate")
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 50)
                        .font(.headline)
                        .foregroundColor(.white)
                        .background(imageLoader.isLoading ? Color.gray : Color.blue)
                        .cornerRadius(10)
                        .padding(.horizontal)
                        .padding(.top, 10)
                        .opacity(imageLoader.isLoading || generateStatus ? 0.5 : 1)
                }
                .disabled(generateStatus || imageLoader.isLoading || !isUsernameValid)
                .alert(item: $imageLoader.error) { error in
                    Alert(
                        title: Text("Error"),
                        message: Text(error.error.localizedDescription),
                        dismissButton: .default(Text("OK"))
                    )                }            }
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
        
    }
}

struct IdentifiableError: Identifiable {
    let id = UUID()
    let error: Error
}

