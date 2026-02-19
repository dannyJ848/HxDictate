import SwiftUI

@main
struct ScribeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @State private var showModelDownload = false
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(AudioSessionManager())
                .environmentObject(TranscriptionEngine())
                .environmentObject(LLMProcessor())
                .onAppear {
                    // Check if models need to be downloaded
                    Task {
                        let needsDownload = !await ModelDownloader.shared.allModelsDownloaded()
                        if needsDownload {
                            await MainActor.run {
                                showModelDownload = true
                            }
                        }
                    }
                }
                .sheet(isPresented: $showModelDownload) {
                    FirstLaunchModelDownloadSheet()
                }
        }
    }
}

struct FirstLaunchModelDownloadSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var downloadProgress: Double = 0
    @State private var isDownloading = false
    @State private var currentModelName: String = ""
    @State private var errorMessage: String?
    @State private var downloadComplete = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Image(systemName: downloadComplete ? "checkmark.circle.fill" : "arrow.down.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(downloadComplete ? .green : .accentColor)
                
                if downloadComplete {
                    Text("Setup Complete!")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("All AI models are ready. Your data stays on device.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    Button("Get Started") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top)
                } else {
                    Text("Welcome to HxDictate")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Download the AI models needed for transcription and note generation. This one-time setup is ~9 GB.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    
                    if isDownloading {
                        VStack(spacing: 12) {
                            ProgressView(value: downloadProgress)
                                .progressViewStyle(.linear)
                                .padding(.horizontal)
                            
                            Text(currentModelName)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text("\(Int(downloadProgress * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical)
                    }
                    
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }
                    
                    Spacer()
                    
                    if !isDownloading {
                        Button {
                            isDownloading = true
                            errorMessage = nil
                            Task {
                                await downloadAllModels()
                            }
                        } label: {
                            Text("Download Models")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical, 40)
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(!downloadComplete)
        }
    }
    
    private func downloadAllModels() async {
        await ModelDownloader.shared.downloadAllModels { modelName, progress in
            Task { @MainActor in
                self.currentModelName = modelName
                self.downloadProgress = progress
            }
        }
        
        let success = await ModelDownloader.shared.allModelsDownloaded()
        
        await MainActor.run {
            if success {
                downloadComplete = true
            } else {
                errorMessage = "Some models failed to download. Check your connection and try again."
                isDownloading = false
            }
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Warm up audio session
        AudioSessionManager.shared.configure()
        return true
    }
}
