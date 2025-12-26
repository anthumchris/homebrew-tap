class GnupgAT25 < Formula
  desc "GNU Privacy Guard (OpenPGP) - production-ready pre 2.6-stable release"
  homepage "https://lists.gnupg.org/pipermail/gnupg-announce/2025q4/000499.html"
  url "https://gnupg.org/ftp/gcrypt/gnupg/gnupg-2.5.14.tar.bz2"
  sha256 "25a622e625a1cc9078b5e3f7adf2bd02b86759170e2fbb8542bca8e907214610"
  license "GPL-3.0-or-later"

  # update udring testing to create diff to force build
  #   nonce = 4

  bottle do
    root_url "https://github.com/anthumchris/homebrew-tap/releases/download/gnupg@2.5-2.5.14"
    rebuild 6
    sha256 arm64_tahoe:     "f0f2f43884ec04035fa23d7e69f083944ccab409b20ce5d462f9b6b3ba39e56b"
    sha256 arm64_sonoma:    "83b32cd9d28299f12361aa32236d172d65c0bee7f31f615226bae06c3f0c2670"
    sha256 x86_64_sequoia:  "6e6d39424f84691058feb2aa1f3bfb8fcd092f7aa68823be4c49f82bb139b853"
    sha256 arm64_linux:     "1f809f36cdd752b948de39f3b98fdf16694379267bdc028f350c40dc0f4e0661"
    sha256 x86_64_linux:    "f7b290dc086a958a95a137d7f00a1f9fd66e20178565f4e51fbbdac32c54160e"
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
