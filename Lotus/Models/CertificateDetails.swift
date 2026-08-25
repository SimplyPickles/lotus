//
//  CertificateDetails.swift
//  Lotus
//
//  Created by Dylan Fraser on 8/24/26.
//

import Foundation
import Security
import CryptoKit

struct CertificateDetails: Identifiable, Equatable {
    let id = UUID()
    let host: String
    let subjectCommonName: String
    let subjectOrganization: String?
    let issuerCommonName: String
    let issuerOrganization: String?
    let validFrom: Date?
    let validUntil: Date?
    let sha256Fingerprint: String
    let keyAlgorithm: String
    let isTrusted: Bool
    let chainCount: Int

    static func from(trust: SecTrust, host: String) -> CertificateDetails? {
        let certificateChain: [SecCertificate]
        if #available(macOS 12.0, *) {
            certificateChain = (SecTrustCopyCertificateChain(trust) as? [SecCertificate]) ?? []
        } else {
            let count = SecTrustGetCertificateCount(trust)
            var chain: [SecCertificate] = []
            for i in 0..<count {
                if let cert = SecTrustGetCertificateAtIndex(trust, i) {
                    chain.append(cert)
                }
            }
            certificateChain = chain
        }

        guard let leafCert = certificateChain.first else { return nil }

        let subjectCN = (SecCertificateCopySubjectSummary(leafCert) as String?) ?? host
        let certData = SecCertificateCopyData(leafCert) as Data
        let sha256 = SHA256.hash(data: certData).map { String(format: "%02X", $0) }.joined(separator: ":")

        var isTrusted = false
        var error: CFError?
        if SecTrustEvaluateWithError(trust, &error) {
            isTrusted = true
        }

        // Parse certificate dictionary values
        var issuerCN = "Certificate Authority"
        var issuerOrg: String?
        var subjectOrg: String?
        var validFrom: Date?
        var validUntil: Date?

        if let values = SecCertificateCopyValues(leafCert, nil, nil) as? [CFString: [CFString: Any]] {
            if let issuerDict = values[kSecOIDX509V1IssuerName]?[kSecPropertyKeyValue] as? [[CFString: Any]] {
                for entry in issuerDict {
                    if let label = entry[kSecPropertyKeyLabel] as? String,
                       let val = entry[kSecPropertyKeyValue] as? String {
                        if label.contains("Common Name") || label == "2.5.4.3" {
                            issuerCN = val
                        } else if label.contains("Organization") || label == "2.5.4.10" {
                            issuerOrg = val
                        }
                    }
                }
            }
            if let subjectDict = values[kSecOIDX509V1SubjectName]?[kSecPropertyKeyValue] as? [[CFString: Any]] {
                for entry in subjectDict {
                    if let label = entry[kSecPropertyKeyLabel] as? String,
                       let val = entry[kSecPropertyKeyValue] as? String {
                        if label.contains("Organization") || label == "2.5.4.10" {
                            subjectOrg = val
                        }
                    }
                }
            }
            if let validityDict = values[kSecOIDX509V1ValidityNotBefore]?[kSecPropertyKeyValue] as? [CFString: Any],
               let dateVal = validityDict[kSecPropertyKeyValue] as? Date {
                validFrom = dateVal
            }
            if let validityDict = values[kSecOIDX509V1ValidityNotAfter]?[kSecPropertyKeyValue] as? [CFString: Any],
               let dateVal = validityDict[kSecPropertyKeyValue] as? Date {
                validUntil = dateVal
            }
        }

        return CertificateDetails(
            host: host,
            subjectCommonName: subjectCN,
            subjectOrganization: subjectOrg,
            issuerCommonName: issuerCN,
            issuerOrganization: issuerOrg,
            validFrom: validFrom,
            validUntil: validUntil,
            sha256Fingerprint: sha256,
            keyAlgorithm: "RSA / ECC 256-bit",
            isTrusted: isTrusted,
            chainCount: certificateChain.count
        )
    }
}
