/// Copyright (c) 2019 Razeware LLC
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
///
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import UIKit
import Geocache

class CachesViewController: UIViewController {
    // MARK: - Properties
    @IBOutlet weak var inProgressCollectionView: UICollectionView!
    @IBOutlet weak var completedCollectionView: UICollectionView!

    // Initial in-progress geocaches are loaded from a .plist
    private lazy var inProgressDataSource: CachesDataSource = {
        guard let path = Bundle.main.path(forResource: "Geocaches", ofType: "plist")
                else {
            print("Failed to read Geocaches.plist")
            return CachesDataSource(geocaches: [])
        }

        let fileUrl = URL.init(fileURLWithPath: path)

        guard let geocachesArray = NSArray(contentsOf: fileUrl) as? [[String: Any]]
                else {
            return CachesDataSource(geocaches: [])
        }

        let geocaches: [Geocache] = geocachesArray.compactMap({ (geocache) in
            guard
                    let name = geocache[Geocache.Key.name] as? String,
                    let summary = geocache[Geocache.Key.summary] as? String,
                    let latitude = geocache[Geocache.Key.latitude] as? Double,
                    let longitude = geocache[Geocache.Key.longitude] as? Double,
                    let imageName = geocache[Geocache.Key.image] as? String,
                    let image = UIImage(named: imageName)?.pngData()
                    else {
                return nil
            }

            return Geocache(
                    name: name, summary: summary,
                    latitude: latitude, longitude: longitude, image: image)
        })
        return CachesDataSource(geocaches: geocaches)
    }()

    // Initial completed geocaches are empty
    private var completedDataSource = CachesDataSource(geocaches: [])

    // MARK: - Lifecycle methods
    override func viewDidLoad() {
        super.viewDidLoad()
        for collectionView in [inProgressCollectionView, completedCollectionView] {
            if let collectionView = collectionView {
                collectionView.dataSource = dataSourceForCollectionView(collectionView)
                collectionView.delegate = self
                collectionView.dragDelegate = self
                collectionView.dropDelegate = self
            }
        }
    }

}

// MARK: - Private methods
private extension CachesViewController {
    func dataSourceForCollectionView(
            _ collectionView: UICollectionView
    ) -> CachesDataSource {
        if collectionView == inProgressCollectionView {
            return inProgressDataSource
        } else {
            return completedDataSource
        }
    }
}

// MARK: - UICollectionViewDelegateFlowLayout
extension CachesViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: collectionView.bounds.width, height: 100)
    }
}

extension CachesViewController: UICollectionViewDragDelegate {
    func collectionView(_ collectionView: UICollectionView,
                        itemsForBeginning session: UIDragSession,
                        at indexPath: IndexPath) -> [UIDragItem] {
        let dataSource = dataSourceForCollectionView(collectionView)

        let dragCoordinator = CacheDragCoordinator(sourceIndexPath: indexPath)
        session.localContext = dragCoordinator

        return dataSource.dragItems(for: indexPath)
    }

    func collectionView(_ collectionView: UICollectionView,
                        dragSessionDidEnd session: UIDragSession) {
        // 1
        guard
                let dragCoordinator = session.localContext as? CacheDragCoordinator,
                dragCoordinator.dragCompleted == true,
                dragCoordinator.isReordering == false
                else {
            return
        }
        // 2
        let dataSource = dataSourceForCollectionView(collectionView)
        let sourceIndexPath = dragCoordinator.sourceIndexPath
        // 3
        collectionView.performBatchUpdates({
            dataSource.deleteGeocache(at: sourceIndexPath.item)
            collectionView.deleteItems(at: [sourceIndexPath])
        })
    }

}

extension CachesViewController: UICollectionViewDropDelegate {
    func collectionView(
            _ collectionView: UICollectionView,
            performDropWith coordinator: UICollectionViewDropCoordinator) {
        // 1
        let dataSource = dataSourceForCollectionView(collectionView)
        // 2
        let destinationIndexPath: IndexPath
        if let indexPath = coordinator.destinationIndexPath {
            destinationIndexPath = indexPath
        } else {
            destinationIndexPath = IndexPath(
                    item: collectionView.numberOfItems(inSection: 0),
                    section: 0)
        }

        // 3
        let item = coordinator.items[0]
        // 4
        switch coordinator.proposal.operation {
        case .move:
            // 1
            guard let dragCoordinator =
            coordinator.session.localDragSession?.localContext as? CacheDragCoordinator
                    else {
                return
            }
// 2
            if let sourceIndexPath = item.sourceIndexPath {
                print("Moving within the same collection view...")
                // 3
                dragCoordinator.isReordering = true
                // 4
                collectionView.performBatchUpdates({
                    dataSource.moveGeocache(at: sourceIndexPath.item, to: destinationIndexPath.item)
                    collectionView.deleteItems(at: [sourceIndexPath])
                    collectionView.insertItems(at: [destinationIndexPath])
                })
            } else {
                print("Moving between collection views...")
                // 5
                dragCoordinator.isReordering = false
                // 6
                if let geocache = item.dragItem.localObject as? Geocache {
                    collectionView.performBatchUpdates({
                        dataSource.addGeocache(geocache, at: destinationIndexPath.item)
                        collectionView.insertItems(at: [destinationIndexPath])
                    })
                }
            }
// 7
            dragCoordinator.dragCompleted = true
// 8
            coordinator.drop(item.dragItem, toItemAt: destinationIndexPath)

        case .copy:
            print("Copying from different app...")
            let itemProvider = item.dragItem.itemProvider
            itemProvider.loadObject(ofClass: NSString.self) { string, error in
                if let string = string as? String {
                    let geocache = Geocache(
                            name: string, summary: "Unknown", latitude: 0.0, longitude: 0.0)
                    dataSource.addGeocache(geocache, at: destinationIndexPath.item)
                    DispatchQueue.main.async {
                        collectionView.insertItems(at: [destinationIndexPath])
                    }
                }
            }

        default:
            return
        }
    }

    func collectionView(
            _ collectionView: UICollectionView,
            dropSessionDidUpdate session: UIDropSession,
            withDestinationIndexPath destinationIndexPath: IndexPath?
    ) -> UICollectionViewDropProposal {
        guard session.localDragSession != nil else {
            return UICollectionViewDropProposal(
                    operation: .copy,
                    intent: .insertAtDestinationIndexPath)
        }
        guard session.items.count == 1 else {
            return UICollectionViewDropProposal(operation: .cancel)
        }
        return UICollectionViewDropProposal(
                operation: .move,
                intent: .insertAtDestinationIndexPath)

    }

}
