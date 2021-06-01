//
//  ViewController.swift
//  GIF2MP4
//
//  Created by Chen JmoVxia on 2020/9/3.
//  Copyright © 2020 Chen JmoVxia. All rights reserved.
//

import Cocoa
import DateToolsSwift
import SnapKit

class ViewController: NSViewController {
    
    @IBOutlet weak var cappedResolutionInput: NSTextField!
    @IBOutlet weak var desiredFrameRateInput: NSTextField!
    @IBOutlet var logTextView: NSTextView!
    var cappedResolution: CGFloat? {
        if cappedResolutionInput.stringValue.isEmpty {
            return nil
        }
        return min(max(CGFloat(cappedResolutionInput.floatValue), 240), 1080)
    }
    var desiredFrameRate: CGFloat? {
        if desiredFrameRateInput.stringValue.isEmpty {
            return nil
        }
        return min(max(CGFloat(desiredFrameRateInput.floatValue), 2), 60)
    }
    private lazy var dragView: DragInView = {
        let view = DragInView()
        view.logsUrlCallback = {[weak self] (urls) in
            self?.readLogs(with: urls)
        }
        return view
    }()
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        let formatter = OnlyIntegerValueFormatter()
        cappedResolutionInput.formatter = formatter
        desiredFrameRateInput.formatter = formatter
        append("请拖拽需要转换的视频文件到窗口中")
        view.addSubview(dragView)
        dragView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
    }
}
extension ViewController {
    func readLogs(with urls: [URL]) {
        let cappedResolution = cappedResolution
        let desiredFrameRate = desiredFrameRate
        DispatchQueue.main.async {
            self.logTextView.string = ""
        }
        DispatchQueue.global().async {
            let path = self.foldPath()
            let semap = DispatchSemaphore(value: 0)
            for url in urls {
                let fileName = ((url.absoluteString as NSString).lastPathComponent as NSString).deletingPathExtension
                let tempUrl = URL(fileURLWithPath: path).appendingPathComponent("\(fileName).gif")
                self.append("\n\n开始转换:\(fileName)")
                MP4ToGIF(videoUrl: url).convertAndExport(to: tempUrl, cappedResolution: cappedResolution, desiredFrameRate: desiredFrameRate) { isSuccess in
                    self.append("\n\n转换:\(fileName) \(isSuccess)")
                    semap.signal()
                }
            }
            urls.forEach { _ in
                semap.wait()
            }
            DispatchQueue.main.async {
                self.openFolder(path)
            }
        }
    }
    func openFolder(_ foldPath: String) {
        if !NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: foldPath) {
            append("\n\n打开文件夹失败")
        }else {
            append("\n\n文件夹已经打开")
        }
    }
}
extension ViewController {
    func append(_ string: String) {
        DispatchQueue.main.async {
            self.logTextView.string += string
            self.logTextView.scrollToEndOfDocument(nil)
        }
    }
}
extension ViewController {
    private func foldPath() -> String {
        let fileManager = FileManager.default
        let folderPath = "\(fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first!.relativePath)/GIF/\(Date().format(with: "yyyy-MM-dd HH:mm:ss"))"
        if !fileManager.fileExists(atPath: folderPath) {
            do {
                try fileManager.createDirectory(atPath: folderPath, withIntermediateDirectories: true, attributes: nil)
            } catch {
                append("\n创建文件夹错误 error:\(error)")
            }
        }
        return folderPath
    }
}
