class GnupgAT25 < Formula
  desc "GNU Privacy Guard (OpenPGP) - production-ready pre 2.6-stable release"
  homepage "https://lists.gnupg.org/pipermail/gnupg-announce/2025q4/000500.html"
  url "https://gnupg.org/ftp/gcrypt/gnupg/gnupg-2.5.16.tar.bz2"
  sha256 "05144040fedb828ced2a6bafa2c4a0479ee4cceacf3b6d68ccc75b175ac13b7e"
  license "GPL-3.0-or-later"

  # update during testing to force bottle/binary builds from this diff
  #   nonce = 4

  bottle do
    root_url "https://github.com/anthumchris/homebrew-tap/releases/download/gnupg@2.5-2.5.16"
    sha256 arm64_tahoe:  "be2da4ea7bea6124a9f700cea1872e17817ffcad89212cceba62dce134df39b9"
    sha256 arm64_sonoma: "1ec3511fd8a5c824a0abe9026fcea2e6f32ff27c1aedf55643126358a63496a5"
    sha256 arm64_linux:  "017acf6334203f8b71b1b2be94f0c2cf64ddda8e8abd7e1a8fe04844abb07575"
    sha256 x86_64_linux: "9044ae92cd96498032f4470e84c8b36d5f99fe5529c1569c80854e951dc5a00b"
  end

  keg_only :versioned_formula

  depends_on "pkgconf" => :build      # enables: Keyboxd, TOFU support
  depends_on "gnutls"                 # enables: Dirmngr, LDAP support, TLS support, Tor support (complete)
  depends_on "libassuan"              # required
  depends_on "libgcrypt"              # required
  depends_on "libgpg-error"           # required
  depends_on "libksba"                # required
  depends_on "libusb"                 # enables: Smartcard (complete)
  depends_on "npth"                   # required
  depends_on "pinentry"               # ensures key passphrase entry
  depends_on "readline"               # enables: Readline support

  on_macos do
    depends_on "gettext"
  end

  on_linux do
    depends_on "bzip2"
    depends_on "sqlite"
    depends_on "zlib"
  end

  def install
    mkdir "build" do
      system "../configure",
        "--disable-silent-rules",
        "--enable-all-tests",
        "--sysconfdir=#{etc}",
        "--with-pinentry-pgm=#{Formula["pinentry"].opt_bin}/pinentry",
        "--with-readline=#{Formula["readline"].opt_prefix}",
        *std_configure_args

      system "make"
      # system "make", "check"        # inactive to satisfy "$ brew audit --strict"
      system "make", "install"
    end
  end

  def post_install
    (var/"run").mkpath

    # stop pre-existing gpg daemons to ensure this new version runs
    quiet_system bin/"gpgconf", "--kill", "all"
  end

  test do
    gpg_flags = "--batch", "--passphrase", ""
    user_id = "test@test"

    begin
      # pinentry is executable, which provides key passphrase entry:
      #   gpg --quick-generate-key --batch --pinentry ask pinentry@test
      system "test", "-x", "#{Formula["pinentry"].opt_bin}/pinentry"

      # readline lib exists
      libreadline_ext = OS.mac? ? "dylib" : "so"
      system "test", "-f", "#{Formula["readline"].opt_lib}/libreadline.#{libreadline_ext}"

      # cert,sign primary key is created with post-quantum computing (PQC) algo
      system bin/"gpg", *gpg_flags, "--quick-gen-key", user_id, "pqc", "cert,sign", "never"

      # get fingerprint of primary key
      fpr = `#{bin}/gpg --list-keys --with-colons #{user_id} | grep fpr | awk -F: '{print \$10}'`.chomp

      # PQC encryption key is added
      system bin/"gpg", *gpg_flags, "--quick-add-key", fpr, "pqc", "encr", "never"

      # file is encrypted and signed
      file = "test.txt"
      (testpath/file).write "test content"
      system bin/"gpg", *gpg_flags, "--encrypt", "--sign", "--recipient", user_id, file

      # file is verified & decrypted
      system bin/"gpg", *gpg_flags, "--decrypt", "#{file}.gpg"
    ensure
      system bin/"gpgconf", "--kill", "all"
    end
  end
end
