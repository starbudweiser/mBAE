// Décompression zlib par la libz du système (équivalent de zlib.decompress de Python).

import CZlib
import Foundation

public enum Inflate {
    /// Flux zlib complet (en-tête + somme Adler) → octets. `nil` si le flux est invalide ou incomplet.
    /// Les octets qui suivent la fin du flux sont ignorés, comme zlib.decompress.
    public static func zlib(_ input: Data) -> Data? {
        if input.isEmpty { return nil }
        var stream = z_stream()
        guard inflateInit_(&stream, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK else { return nil }
        defer { inflateEnd(&stream) }

        var out = Data()
        var chunk = [UInt8](repeating: 0, count: 1 << 16)
        var status: Int32 = Z_OK
        let ok: Bool = input.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> Bool in
            stream.next_in = UnsafeMutablePointer(mutating: raw.bindMemory(to: UInt8.self).baseAddress!)
            stream.avail_in = uInt(input.count)
            repeat {
                let produced: Int = chunk.withUnsafeMutableBufferPointer { buf in
                    stream.next_out = buf.baseAddress
                    stream.avail_out = uInt(buf.count)
                    status = inflate(&stream, Z_NO_FLUSH)
                    return buf.count - Int(stream.avail_out)
                }
                out.append(chunk, count: produced)
                if status == Z_BUF_ERROR && stream.avail_in == 0 { return false }  // flux tronqué
            } while status == Z_OK
            return status == Z_STREAM_END
        }
        return ok ? out : nil
    }
}
