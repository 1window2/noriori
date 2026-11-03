import Flutter
import UIKit
import UniformTypeIdentifiers

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var backupFolder: BackupFolderChannel?
  private var filePick: FilePickChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    backupFolder = BackupFolderChannel(messenger: engineBridge.applicationRegistrar.messenger())
    filePick = FilePickChannel(messenger: engineBridge.applicationRegistrar.messenger())
  }
}

/// 가져올 파일 하나를 고른다. 사본을 받아 읽으므로 권한을 남기지 않는다.
final class FilePickChannel: NSObject, UIDocumentPickerDelegate {
  private var pending: FlutterResult?

  init(messenger: FlutterBinaryMessenger) {
    super.init()
    let channel = FlutterMethodChannel(name: "app.noriori/file_pick", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "pick" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.pending = result
      let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.data], asCopy: true)
      picker.delegate = self
      var top = UIApplication.shared.connectedScenes
        .compactMap { ($0 as? UIWindowScene)?.keyWindow }.first?.rootViewController
      while let next = top?.presentedViewController { top = next }
      top?.present(picker, animated: true)
    }
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    defer { pending = nil }
    guard let url = urls.first else {
      pending?(nil)
      return
    }
    do {
      let data = try Data(contentsOf: url)
      pending?(["name": url.lastPathComponent, "bytes": FlutterStandardTypedData(bytes: data)])
    } catch {
      pending?(FlutterError(code: "file_pick", message: "\(error)", details: nil))
    }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    pending?(nil)
    pending = nil
  }
}

/// 사용자가 고른 백업 폴더 (ARCHITECTURE §3.7). 책갈피로 다시 연다.
/// 앱 컨테이너 밖이라 앱을 지워도 남는다. 재설치하면 책갈피가 사라져 폴더를 다시 고른다.
final class BackupFolderChannel: NSObject, UIDocumentPickerDelegate {
  private let bookmarkKey = "backup.bookmark"
  private let queue = DispatchQueue(label: "app.noriori.backup")
  private var pending: FlutterResult?
  private var task = UIBackgroundTaskIdentifier.invalid

  init(messenger: FlutterBinaryMessenger) {
    super.init()
    let channel = FlutterMethodChannel(name: "app.noriori/backup_folder", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result)
    }
  }

  private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    switch call.method {
    case "status":
      guard let url = try? resolve() else {
        result(UserDefaults.standard.data(forKey: bookmarkKey) == nil
          ? nil : ["name": "", "granted": false])
        return
      }
      result(["name": url.lastPathComponent, "granted": true])
    case "pick":
      pending = result
      let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
      picker.delegate = self
      var top = UIApplication.shared.connectedScenes
        .compactMap { ($0 as? UIWindowScene)?.keyWindow }.first?.rootViewController
      while let next = top?.presentedViewController { top = next }
      top?.present(picker, animated: true)
    case "names":
      background(result) {
        try self.withFolder { folder in
          try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            .map(\.lastPathComponent)
            .filter { $0.hasSuffix(".json") }
        }
      }
    case "read":
      let name = args?["name"] as? String ?? ""
      background(result) {
        // 내려받지 않은 구름 파일은 읽기가 실패한다. 읽지 못한 파일로 다룬다
        let data = try? self.withFolder { try Data(contentsOf: $0.appendingPathComponent(name)) }
        return data.map { FlutterStandardTypedData(bytes: $0) } as Any
      }
    case "write":
      let name = args?["name"] as? String ?? ""
      let bytes = (args?["bytes"] as? FlutterStandardTypedData)?.data ?? Data()
      background(result) {
        try self.withFolder { try bytes.write(to: $0.appendingPathComponent(name), options: .atomic) }
        return nil
      }
    case "delete":
      let name = args?["name"] as? String ?? ""
      background(result) {
        try self.withFolder { try FileManager.default.removeItem(at: $0.appendingPathComponent(name)) }
        return nil
      }
    case "beginTask":
      guard task == .invalid else { return result(nil) }
      task = UIApplication.shared.beginBackgroundTask(withName: "backup") { [weak self] in
        self?.endTask()
      }
      result(nil)
    case "endTask":
      endTask()
      result(nil)
    case "excludeFromBackup":
      for path in args?["paths"] as? [String] ?? [] {
        var url = URL(fileURLWithPath: path, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
      }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func endTask() {
    guard task != .invalid else { return }
    UIApplication.shared.endBackgroundTask(task)
    task = .invalid
  }

  private func resolve() throws -> URL {
    guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else {
      throw NSError(domain: "backup", code: 1)
    }
    var stale = false
    let url = try URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale)
    if stale, url.startAccessingSecurityScopedResource() {
      defer { url.stopAccessingSecurityScopedResource() }
      if let fresh = try? url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil) {
        UserDefaults.standard.set(fresh, forKey: bookmarkKey)
      }
    }
    return url
  }

  private func withFolder<T>(_ body: (URL) throws -> T) throws -> T {
    let url = try resolve()
    guard url.startAccessingSecurityScopedResource() else {
      throw NSError(domain: "backup", code: 2)
    }
    defer { url.stopAccessingSecurityScopedResource() }
    return try body(url)
  }

  private func background(_ result: @escaping FlutterResult, _ work: @escaping () throws -> Any?) {
    queue.async {
      do {
        let value = try work()
        DispatchQueue.main.async { result(value) }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: "backup_folder", message: "\(error)", details: nil))
        }
      }
    }
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    defer { pending = nil }
    guard let url = urls.first else {
      pending?(nil)
      return
    }
    // 앱 컨테이너 안은 앱을 지우면 함께 사라진다
    let home = URL(fileURLWithPath: NSHomeDirectory()).resolvingSymlinksInPath().path
    let insideApp = url.resolvingSymlinksInPath().path.hasPrefix(home)
    if insideApp {
      pending?(["name": url.lastPathComponent, "insideApp": true])
      return
    }
    do {
      guard url.startAccessingSecurityScopedResource() else {
        throw NSError(domain: "backup", code: 2)
      }
      defer { url.stopAccessingSecurityScopedResource() }
      let data = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
      UserDefaults.standard.set(data, forKey: bookmarkKey)
      pending?(["name": url.lastPathComponent, "insideApp": false])
    } catch {
      pending?(FlutterError(code: "backup_folder", message: "\(error)", details: nil))
    }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    pending?(nil)
    pending = nil
  }
}
