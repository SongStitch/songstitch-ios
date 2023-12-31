import SwiftUI
import UIKit
import Combine

/* Fullscreen image view logic */
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
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.primary)
                            .font(.largeTitle)
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
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isZoomed.toggle()
                            if !isZoomed {
                                offset = .zero
                                lastScaleValue = 1.0
                            }
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
        .padding(3.0)
        .statusBar(hidden: true)
    }
}

/* Image loading logic */
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
                   fontsize: Int,
                   webp: Bool,
                   boldfont: Bool) {
        
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
            URLQueryItem(name: "webp", value: String(webp)),
            URLQueryItem(name: "boldfont", value: String(boldfont)),
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

/* Logic to save to Photos */
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
        if let error = error {
            print("Image save failed: \(error.localizedDescription)")
        } else {
            showToast(message: "Image saved successfully!")
        }
    }
    
    func showToast(message: String) {
        guard let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let window = windowScene.windows.first else {
            return
        }
        
        let toastLabel = UILabel(frame: CGRect(x: 16, y: window.bounds.height - 100, width: window.bounds.width - 32, height: 40))
        
        if #available(iOS 13.0, *) {
            let backgroundColor = UIColor { (traitCollection) -> UIColor in
                if traitCollection.userInterfaceStyle == .dark {
                    return UIColor.white.withAlphaComponent(0.6)
                } else {
                    return UIColor.black.withAlphaComponent(0.6)
                }
            }
            
            toastLabel.backgroundColor = backgroundColor
            
            let textColor = UIColor { (traitCollection) -> UIColor in
                if traitCollection.userInterfaceStyle == .dark {
                    return UIColor.black
                } else {
                    return UIColor.white
                }
            }
            
            toastLabel.textColor = textColor
        } else {
            toastLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
            toastLabel.textColor = UIColor.white
        }
        
        toastLabel.font = UIFont.systemFont(ofSize: 14)
        toastLabel.textAlignment = .center
        toastLabel.text = message
        toastLabel.alpha = 0.0
        toastLabel.layer.cornerRadius = 20
        toastLabel.clipsToBounds = true
        
        window.addSubview(toastLabel)
        
        UIView.animate(withDuration: 0.3, delay: 0.1, options: .curveEaseOut, animations: {
            toastLabel.alpha = 1.0
        }) { (completed) in
            UIView.animate(withDuration: 0.3, delay: 2.0, options: .curveEaseIn, animations: {
                toastLabel.alpha = 0.0
            }) { (completed) in
                toastLabel.removeFromSuperview()
            }
        }
    }
}


/* Share sheet options */
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<ShareSheet>) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: [SaveToPhotosActivity()])
        controller.excludedActivityTypes = [.addToReadingList, .openInIBooks]
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
    @State var webp: Bool = false
    @State var boldfont: Bool = false
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
    @State private var showMoreToggles = false
    @State private var imageOffset = CGSize(width: 0, height: -UIScreen.main.bounds.height)
    @State var buttonOpacity: Double = 0
    
    
    
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
                              fontsize: fontsize,
                              webp: webp,
                              boldfont: boldfont
                              
                              
        )
        isShowingImage = imageLoader.errorMessage == nil
    }
    
    init() {
        
        _username = State(initialValue: UserDefaults.standard.string(forKey: "Username") ?? "")
        UISplitViewController().preferredDisplayMode = .twoDisplaceSecondary
        
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
                        Form {
                            Section(header: Text("")
                                .frame(maxWidth: .infinity)
                                .font(.headline)
                            ){
                                VStack {
                                    VStack {
                                        Image("logo")
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .cornerRadius(5)
                                            .frame(maxWidth: .infinity, maxHeight: 50)
                                        Text("Collage Type")
                                            .font(.headline)
                                            .padding(.top, 10   )
                                        Picker(selection: $method, label: Text("Collage")) {
                                            Text("Top Albums").tag("album")
                                            Text("Top Artists").tag("artist")
                                            Text("Top Tracks").tag("track")
                                        }
                                        .pickerStyle(SegmentedPickerStyle())
                                        .accentColor(.blue)
                                        .onChange(of: method) { _ in
                                            if method == "album" {
                                                rows = min(rows, 15)
                                                columns = min(columns, 15)
                                            } else if method == "track" {
                                                rows = min(rows, 5)
                                                columns = min(columns, 5)
                                            } else {
                                                rows = min(rows, 10)
                                                columns = min(columns, 10)
                                            }
                                        }
                                    }
                                    Text("Last.fm Username")
                                        .font(.headline)
                                        .padding(.top, 20)
                                    TextField("Last.FM Username", text: $username, onEditingChanged: { _ in
                                    })  .focused($isInputActive)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
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
                                        }
                                        
                                        if method != "artist" {
                                            Toggle(isOn: $album) {
                                                Text("Album Name")
                                            }.toggleStyle(SwitchToggleStyle(tint: .blue))
                                        }
                                        if method == "track" {
                                            Toggle(isOn: $track) {
                                                Text("Track Name")
                                            }.toggleStyle(SwitchToggleStyle(tint: .blue))
                                        }
                                        Toggle(isOn: $artist) {
                                            Text("Artist Name")
                                        }.toggleStyle(SwitchToggleStyle(tint: .blue))
                                        Toggle(isOn: $playcount) {
                                            Text("Play Count")
                                        }.toggleStyle(SwitchToggleStyle(tint: .blue))
                                            .padding(.bottom, 10)
                                        
                                        var stepperRange: ClosedRange<Int> {
                                            if method == "album" {
                                                return 1...15
                                            } else if method == "track" {
                                                return 1...5
                                            } else {
                                                return 1...10
                                            }
                                        }
                                        VStack {
                                            Stepper(value: $rows, in: stepperRange) {
                                                Text("Rows: \(rows)")
                                            }
                                            Stepper(value: $columns, in: stepperRange) {
                                                Text("Columns: \(columns)")
                                            }
                                        }
                                        .padding(.top, 10)
                                        
                                        VStack {
                                            Toggle(isOn: $showMoreToggles) {
                                                Text("Advanced Options")
                                            }.toggleStyle(SwitchToggleStyle(tint: .blue))
                                                .padding(.top, 10)
                                            if showMoreToggles {
                                                HStack {
                                                    VStack {
                                                        Text("Text Font Size")
                                                        Picker("Font Size", selection: $fontsize) {
                                                            Text("Extra Small").tag(10)
                                                            Text("Small").tag(12)
                                                            Text("Medium").tag(16)
                                                            Text("Large").tag(20)
                                                        }
                                                        .pickerStyle(SegmentedPickerStyle())
                                                    }.padding(.top, 10)
                                                        .padding(.bottom, 20)
                                                }
                                                Toggle(isOn: $webp) {
                                                    Text("WebP Compressed Image")
                                                }.toggleStyle(SwitchToggleStyle(tint: .blue))
                                                    .padding(.bottom, 10)
                                                Toggle(isOn: $boldfont) {
                                                    Text("Use Bold Font")
                                                }.toggleStyle(SwitchToggleStyle(tint: .blue))
                                                    .padding(.bottom, 10)
                                            }
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
                        .padding(.top, 0)
                        .padding(.bottom, 50)
                        
                    }
                }
                VStack {
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
                                .frame(maxWidth: UIScreen.main.bounds.width * 0.95, maxHeight: .infinity)
                                .clipShape(Rectangle())
                                .padding(.top, 20)
                                .padding(.bottom, 20)
                        }
                        .transition(.move(edge: .top))
                        .fullScreenCover(isPresented: $isShowingFullscreenImage) {
                            withAnimation {
                                FullscreenImageView(isPresented: $isShowingFullscreenImage, image: image)
                            }
                        }
                        .onAppear {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                imageOffset = CGSize(width: 0, height: 0)                            }
                        }
                        .onDisappear {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                imageOffset = CGSize(width: 0, height: -UIScreen.main.bounds.height)
                                
                            }
                        }
                        .offset(imageOffset)
                        
                        .buttonStyle(PlainButtonStyle())
                        .onTapGesture {
                            presentationMode.wrappedValue.dismiss()
                        }
                        
                        
                        VStack {
                            withAnimation {
                                Text("Tap the Image to view in fullscreen")
                                    .opacity(isShowingFullscreenImage ? 0 : 1)
                                    .padding(.bottom, 10)
                                    .font(.system(size: 14, weight: .thin))
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
                                    withAnimation(.easeInOut(duration: 0.5)) {
                                        imageLoader.image = nil
                                    }
                                    withAnimation(.easeInOut(duration: 0.5)) {
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
                            }
                            
                        }     .opacity(buttonOpacity)
                            .onAppear {
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    buttonOpacity = 1                          }
                            }
                            .onDisappear {
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    buttonOpacity = 0
                                }
                            }
                        
                        
                    }
                    Spacer()
                    
                    if imageLoader.isLoading {
                        ZStack {
                            Color.clear
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            VStack {
                                Spacer()
                                `ProgressView`()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .scaleEffect(2.0)
                                Spacer()
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    
                    
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
                                              fontsize: fontsize,
                                              webp: webp,
                                              boldfont: boldfont
                        )
                        isShowingImage = imageLoader.errorMessage == nil
                    }
                    ) {
                        Text(imageLoader.isLoading ? "Generating..." : "Generate")
                            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 50)
                            .edgesIgnoringSafeArea(.bottom)
                            .font(.headline)
                            .foregroundColor(.white)
                            .background(
                                ZStack {
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.blue, Color.purple]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                    .cornerRadius(15)
                                    .opacity(0.8)
                                    
                                    if imageLoader.isLoading {
                                        Color.gray
                                    }
                                }
                            )
                            .background(imageLoader.isLoading ? Color.gray : Color.blue)
                            .cornerRadius(15)
                            .padding(.horizontal)
                            .padding(.top, 10)
                            .padding(.bottom, 10)
                            .zIndex(-1)
                            .opacity(imageLoader.isLoading || generateStatus ? 0.5 : 1)
                    }
                    .disabled(generateStatus || imageLoader.isLoading || isShowingImage || username == "")
                    .opacity((username == "") ? 0.5 : 1)
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
            UIScrollView.appearance().keyboardDismissMode = .onDrag
            
        }
        .alert(item: $imageLoader.error) { error in
            Alert(
                title: Text("Error"),
                message: Text(error.error.localizedDescription),
                dismissButton: .default(Text("OK"))
            )
        }
        .onChange(of: imageLoader.errorHasOccurred) { newValue in
            if !newValue {
                isShowingError = false
                isShowingImage = imageLoader.image != nil
            } else {
                isShowingError = true
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
        }
        .padding(.top, 0)
        .padding(.bottom, 0)
        .edgesIgnoringSafeArea(.bottom)
    }
}

struct IdentifiableError: Identifiable {
    let id = UUID()
    let error: Error
}
