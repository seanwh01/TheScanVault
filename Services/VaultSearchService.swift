            let items = documents.compactMap { document -> DocumentListItem? in
                guard let id = document.entityId as? UUID,
                      let title = document.title,
                      let createdAt = document.creationDate
                else {
                    return nil
                }
                
                // Check if document is in a folder
                var folderName: String? = nil
                if let folder = document.folder, let name = folder.name {
                    folderName = name
                }
                
                // Extract all tag names
                var tagNames: [String] = []
                if let tags = document.tags as? Set<Tag> {
                    tagNames = tags.compactMap { $0.name }
                }

                return DocumentListItem(
                    id: id,
                    title: title,
                    createdAt: createdAt,
                    folderName: folderName,
                    tagNames: tagNames,
                    isLocked: document.isLocked
                )
            } 