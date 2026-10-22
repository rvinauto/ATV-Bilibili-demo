import Foundation
import TVServices

final class ContentProvider: TVTopShelfContentProvider {
    private struct PopularResponse: Decodable {
        struct DataContainer: Decodable {
            struct Video: Decodable {
                let aid: Int
                let cid: Int
                let title: String
                let pic: String
            }

            let list: [Video]
        }

        let code: Int
        let data: DataContainer?
    }

    override func loadTopShelfContent(
        completionHandler: @escaping (TVTopShelfContent?) -> Void
    ) {
        var components = URLComponents(string: "https://api.bilibili.com/x/web-interface/popular")
        components?.queryItems = [
            URLQueryItem(name: "ps", value: "5"),
            URLQueryItem(name: "pn", value: "1"),
        ]

        guard let url = components?.url else {
            completionHandler(Self.fallbackContent())
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.setValue("BiLiBiLi AppleTV Client/1.0.0", forHTTPHeaderField: "User-Agent")
        request.setValue("https://www.bilibili.com/", forHTTPHeaderField: "Referer")

        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard
                let data,
                let response = try? JSONDecoder().decode(PopularResponse.self, from: data),
                response.code == 0,
                let videos = response.data?.list,
                !videos.isEmpty
            else {
                completionHandler(Self.fallbackContent())
                return
            }

            let items = videos.prefix(5).compactMap(Self.makeItem)
            guard !items.isEmpty else {
                completionHandler(Self.fallbackContent())
                return
            }

            let section = TVTopShelfItemCollection(items: items)
            section.title = "Bilibili 热门"
            completionHandler(TVTopShelfSectionedContent(sections: [section]))
        }.resume()
    }

    private static func makeItem(
        from video: PopularResponse.DataContainer.Video
    ) -> TVTopShelfSectionedItem? {
        guard
            let imageURL = normalizedImageURL(video.pic),
            let actionURL = URL(string: "bilibili-live://video?aid=\(video.aid)&cid=\(video.cid)")
        else {
            return nil
        }

        let item = TVTopShelfSectionedItem(identifier: "av-\(video.aid)-\(video.cid)")
        item.title = video.title
        item.imageShape = .hdtv
        item.setImageURL(imageURL, for: .screenScale1x)
        item.setImageURL(imageURL, for: .screenScale2x)
        item.displayAction = TVTopShelfAction(url: actionURL)
        return item
    }

    private static func normalizedImageURL(_ raw: String) -> URL? {
        if raw.hasPrefix("//") {
            return URL(string: "https:\(raw)")
        }
        return URL(string: raw)
    }

    private static func fallbackContent() -> TVTopShelfContent? {
        guard
            let imageURL = URL(string: "https://raw.githubusercontent.com/yichengchen/ATV-Bilibili-demo/main/BilibiliLive/Supporting%20Files/Assets.xcassets/App%20Icon%20%26%20Top%20Shelf%20Image.brandassets/Top%20Shelf%20Image%20Wide.imageset/Bilibili-Wallpapers-3.jpg"),
            let actionURL = URL(string: "bilibili-live://home")
        else {
            return nil
        }

        let item = TVTopShelfSectionedItem(identifier: "bilibili-live-home")
        item.title = "打开 BilibiliLive"
        item.imageShape = .hdtv
        item.setImageURL(imageURL, for: .screenScale1x)
        item.setImageURL(imageURL, for: .screenScale2x)
        item.displayAction = TVTopShelfAction(url: actionURL)

        let section = TVTopShelfItemCollection(items: [item])
        section.title = "BilibiliLive"
        return TVTopShelfSectionedContent(sections: [section])
    }
}
