import Foundation

enum FileAccessError {
    static func userMessage(for error: Error) -> String {
        let nsError = error as NSError

        if nsError.domain == NSCocoaErrorDomain {
            switch nsError.code {
            case NSFileReadNoPermissionError, NSFileWriteNoPermissionError:
                return "\(AppBrand.name) doesn't have permission to access this file. Check folder permissions in Finder."
            case NSFileWriteVolumeReadOnlyError:
                return "This volume is read-only. \(AppBrand.name) can't save changes here."
            case NSFileNoSuchFileError:
                return "The file no longer exists. Try refreshing the catalog."
            default:
                break
            }
        }

        if nsError.domain == NSPOSIXErrorDomain, nsError.code == Int(EACCES) {
            return "\(AppBrand.name) doesn't have permission to access this file. Check folder permissions in Finder."
        }

        return error.localizedDescription
    }
}
