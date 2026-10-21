import com.android.apksig.ApkSigner;
import com.android.apksig.ApkVerifier;
import java.io.File;
import java.io.FileInputStream;
import java.nio.file.Files;
import java.nio.file.StandardCopyOption;
import java.security.KeyStore;
import java.security.PrivateKey;
import java.security.cert.Certificate;
import java.security.cert.X509Certificate;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.zip.ZipFile;
import java.io.FileOutputStream;
import java.security.cert.CertificateFactory;
import jdk.security.jarsigner.JarSigner;

/**
 * Minimal drop-in replacement for the Android SDK "apksigner" tool, built on
 * apksig 2.3.0 from Maven Central (dl.google.com is unreachable in CI).
 * Supports the subset of arguments used by the Godot Android exporter:
 *   sign --ks <file> --ks-pass pass:<pw> --ks-key-alias <alias> [--key-pass pass:<pw>] <apk>
 *   verify [--verbose] <apk>
 * Produces v1 (JAR, via the JDK's jdk.security.jarsigner API) + v2 (APK Signature
 * Scheme v2, via apksig, which also re-aligns uncompressed entries) signatures.
 */
public class ApkSignerShim {
    static String pass(String v) {
        if (v == null) return null;
        if (v.startsWith("pass:")) return v.substring(5);
        if (v.startsWith("env:")) return System.getenv(v.substring(4));
        return v;
    }


    /** Raw zip re-writer that pads STORED entries (4 bytes, 4096 for .so) like the SDK's zipalign -p. */
    static void zipalign(File src, File dst) throws Exception {
        byte[] d = Files.readAllBytes(src.toPath());
        java.nio.ByteBuffer b = java.nio.ByteBuffer.wrap(d).order(java.nio.ByteOrder.LITTLE_ENDIAN);
        int eocd = -1;
        for (int i = d.length - 22; i >= Math.max(0, d.length - 22 - 65535); i--) if (b.getInt(i) == 0x06054b50) { eocd = i; break; }
        if (eocd < 0) throw new IllegalStateException("EOCD not found");
        int count = b.getShort(eocd + 10) & 0xffff;
        int cdOff = b.getInt(eocd + 16);
        java.io.ByteArrayOutputStream out = new java.io.ByteArrayOutputStream(d.length + 65536);
        java.io.ByteArrayOutputStream cd = new java.io.ByteArrayOutputStream();
        int p = cdOff;
        for (int n = 0; n < count; n++) {
            int nameLen = b.getShort(p + 28) & 0xffff, extraLen = b.getShort(p + 30) & 0xffff, comLen = b.getShort(p + 32) & 0xffff;
            int lho = b.getInt(p + 42);
            int method = b.getShort(lho + 8) & 0xffff;
            int lName = b.getShort(lho + 26) & 0xffff, lExtra = b.getShort(lho + 28) & 0xffff;
            int flags = b.getShort(lho + 6) & 0xffff;
            long csize = b.getInt(p + 20) & 0xffffffffL;
            String name = new String(d, p + 46, nameLen, java.nio.charset.StandardCharsets.UTF_8);
            int newOff = out.size();
            int dataStart = newOff + 30 + lName;
            int pad = 0;
            if (method == 0) { int al = name.endsWith(".so") ? 4096 : 4; pad = (al - (dataStart % al)) % al; }
            // local header with extra field replaced by zero padding
            out.write(d, lho, 26);
            out.write(lName & 0xff); out.write(lName >> 8);
            out.write(pad & 0xff); out.write(pad >> 8);
            out.write(d, lho + 30, lName);
            out.write(new byte[pad]);
            out.write(d, lho + 30 + lName + lExtra, (int) csize);
            if ((flags & 8) != 0) { // data descriptor
                int dd = lho + 30 + lName + lExtra + (int) csize;
                int ddLen = b.getInt(dd) == 0x08074b50 ? 16 : 12;
                out.write(d, dd, ddLen);
            }
            byte[] rec = java.util.Arrays.copyOfRange(d, p, p + 46 + nameLen + extraLen + comLen);
            java.nio.ByteBuffer.wrap(rec).order(java.nio.ByteOrder.LITTLE_ENDIAN).putInt(42, newOff);
            cd.write(rec);
            p += 46 + nameLen + extraLen + comLen;
        }
        int newCd = out.size();
        out.write(cd.toByteArray());
        byte[] e = java.util.Arrays.copyOfRange(d, eocd, d.length);
        java.nio.ByteBuffer eb = java.nio.ByteBuffer.wrap(e).order(java.nio.ByteOrder.LITTLE_ENDIAN);
        eb.putInt(12, cd.size()); eb.putInt(16, newCd);
        out.write(e);
        Files.write(dst.toPath(), out.toByteArray());
    }

    public static void main(String[] args) throws Exception {
        if (args.length == 0) { System.err.println("usage: apksigner sign|verify ..."); System.exit(2); }
        String cmd = args[0];
        if (cmd.equals("--version") || cmd.equals("version")) { System.out.println("0.9"); return; }
        String ks = null, ksPass = null, alias = null, keyPass = null, apk = null, out = null;
        for (int i = 1; i < args.length; i++) {
            String a = args[i];
            switch (a) {
                case "--ks": ks = args[++i]; break;
                case "--ks-pass": ksPass = pass(args[++i]); break;
                case "--ks-key-alias": alias = args[++i]; break;
                case "--key-pass": keyPass = pass(args[++i]); break;
                case "--out": out = args[++i]; break;
                case "--verbose": case "-v": case "--print-certs": break;
                default:
                    if (a.startsWith("--")) {
                        // Flags with a value we do not need (e.g. --v4-signing-enabled false, --min-sdk-version N).
                        if (i + 1 < args.length && !args[i + 1].startsWith("--") && !args[i + 1].endsWith(".apk")) i++;
                    } else {
                        apk = a;
                    }
            }
        }
        if (apk == null) { System.err.println("No APK given"); System.exit(2); }
        File in = new File(apk);
        if (cmd.equals("verify")) {
            ApkVerifier.Result r = new ApkVerifier.Builder(in).build().verify();
            System.out.println("Verifies: " + r.isVerified());
            System.out.println("Verified using v1 scheme (JAR signing): " + r.isVerifiedUsingV1Scheme());
            System.out.println("Verified using v2 scheme (APK Signature Scheme v2): " + r.isVerifiedUsingV2Scheme());
            for (ApkVerifier.IssueWithParams e : r.getErrors()) System.err.println("ERROR: " + e);
            System.exit(r.isVerified() ? 0 : 1);
        }
        if (!cmd.equals("sign")) { System.err.println("Unknown command " + cmd); System.exit(2); }
        if (keyPass == null) keyPass = ksPass;
        KeyStore store = KeyStore.getInstance(KeyStore.getDefaultType());
        try (FileInputStream fis = new FileInputStream(ks)) { store.load(fis, ksPass.toCharArray()); }
        if (alias == null) alias = Collections.list(store.aliases()).get(0);
        PrivateKey key = (PrivateKey) store.getKey(alias, keyPass.toCharArray());
        List<X509Certificate> certs = new ArrayList<>();
        for (Certificate c : store.getCertificateChain(alias)) certs.add((X509Certificate) c);
        ApkSigner.SignerConfig sc = new ApkSigner.SignerConfig.Builder("CERT", key, certs).build();
        File dir = in.getAbsoluteFile().getParentFile();
        // Step 1: v1 JAR signature with the JDK signer (apksig 2.3.0's v1 signer relies on removed JDK internals).
        File v1 = File.createTempFile("v1sig", ".apk", dir);
        CertificateFactory cf = CertificateFactory.getInstance("X.509");
        try (ZipFile zf = new ZipFile(in); FileOutputStream fos = new FileOutputStream(v1)) {
            JarSigner.Builder jb = new JarSigner.Builder(key, cf.generateCertPath(certs))
                .digestAlgorithm("SHA-256").signerName("CERT")
                .setProperty("internalsf", "false").setProperty("sectionsonly", "false");
            jb.build().sign(zf, fos);
        }
        File aligned = File.createTempFile("aligned", ".apk", dir);
        zipalign(v1, aligned);
        if (System.getenv("APKSIGNER_DEBUG") != null) Files.copy(aligned.toPath(), new File(dir, "debug_v1_aligned.apk").toPath(), StandardCopyOption.REPLACE_EXISTING);
        v1.delete();
        v1 = aligned;
        // Step 2: v2 signature block computed with apksig's v2 signer and inserted before the
        // central directory (ApkSigner itself would strip the v1 entries when v1 is disabled).
        File tmp = File.createTempFile("signed", ".apk", dir);
        try {
            byte[] d = Files.readAllBytes(v1.toPath());
            java.nio.ByteBuffer b = java.nio.ByteBuffer.wrap(d).order(java.nio.ByteOrder.LITTLE_ENDIAN);
            int eocd = -1;
            for (int i = d.length - 22; i >= 0; i--) if (b.getInt(i) == 0x06054b50) { eocd = i; break; }
            int cdOff = b.getInt(eocd + 16), cdSize = b.getInt(eocd + 12);
            com.android.apksig.internal.apk.v2.V2SchemeSigner.SignerConfig v2c = new com.android.apksig.internal.apk.v2.V2SchemeSigner.SignerConfig();
            v2c.privateKey = key; v2c.certificates = certs;
            v2c.signatureAlgorithms = com.android.apksig.internal.apk.v2.V2SchemeSigner.getSuggestedSignatureAlgorithms(certs.get(0).getPublicKey(), 24);
            byte[] block = com.android.apksig.internal.apk.v2.V2SchemeSigner.generateApkSigningBlock(
                com.android.apksig.util.DataSources.asDataSource(java.nio.ByteBuffer.wrap(d, 0, cdOff).slice()),
                com.android.apksig.util.DataSources.asDataSource(java.nio.ByteBuffer.wrap(d, cdOff, cdSize).slice()),
                com.android.apksig.util.DataSources.asDataSource(java.nio.ByteBuffer.wrap(d, eocd, d.length - eocd).slice()),
                Collections.singletonList(v2c));
            byte[] e = java.util.Arrays.copyOfRange(d, eocd, d.length);
            java.nio.ByteBuffer.wrap(e).order(java.nio.ByteOrder.LITTLE_ENDIAN).putInt(16, cdOff + block.length);
            try (FileOutputStream o = new FileOutputStream(tmp)) {
                o.write(d, 0, cdOff); o.write(block); o.write(d, cdOff, cdSize); o.write(e);
            }
        } finally {
            v1.delete();
        }
        File dest = out != null ? new File(out) : in;
        Files.move(tmp.toPath(), dest.toPath(), StandardCopyOption.REPLACE_EXISTING);
        System.out.println("Signed " + dest);
    }
}
