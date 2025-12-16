class GnupgAT25 < Formula
  desc "GNU Privacy Guard (OpenPGP) - production-ready pre 2.6-stable release"
  homepage "https://lists.gnupg.org/pipermail/gnupg-announce/2025q4/000499.html"
  url "https://gnupg.org/ftp/gcrypt/gnupg/gnupg-2.5.14.tar.bz2"
  sha256 "25a622e625a1cc9078b5e3f7adf2bd02b86759170e2fbb8542bca8e907214610"
  license "GPL-3.0-or-later"

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

  def install
    mkdir "build" do
      system "../configure",
        "--disable-silent-rules",
        "--enable-all-tests",
        "--sysconfdir=#{etc}",
        "--with-agent-pgm=#{bin}/gpg-agent",
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

    # stop daemons for every installed gpg version to ensure this version runs
    quiet_system "which gpgconf | xargs -I {} sh -c '{} --kill all'"
  end

  test do
    (testpath/"batch.gpg").write <<-GPG
      Key-Type: EDDSA
      Key-Curve: ed25519
      Key-Usage: cert,sign
      Subkey-Type: ECDH
      Subkey-Curve: cv25519
      Subkey-Usage: encrypt
      Name-Real: test
      Name-Email: test@test
      Expire-Date: 1d
      %no-protection
      %commit
    GPG

    # avoid collisions with other installed gpg-agents
    #   gpg: WARNING: server 'gpg-agent' is older than us (2.2.x < 2.5.x)
    agent = "--agent-program", "#{bin}/gpg-agent"

    system "gpg", "--version"
    puts ENV["PATH"]

    begin
      # pinentry is executable, which provides key passphrase entry:
      #   gpg --quick-generate-key --batch --pinentry ask pinentry@test
      system "test", "-x", "#{Formula["pinentry"].opt_bin}/pinentry"

      # readline lib exists
      libreadline_ext = OS.mac? ? "dylib" : "so"
      system "test", "-f", "#{Formula["readline"].opt_lib}/libreadline.#{libreadline_ext}"

      # keys are created
      system bin/"gpg", *agent, "--batch", "--gen-key", "batch.gpg"

      # file is encrypted and signed
      file = "test.txt"
      (testpath/file).write "test content"
      system bin/"gpg", *agent, "--encrypt", "--sign", "--recipient", "test@test", file

      # system "#{bin}/gpgconf --list-dirs | sort"

      # file is decrypted
      system bin/"gpg", *agent, "--decrypt", "#{file}.gpg"
    ensure
      system bin/"gpgconf", "--kill", "all"
    end
  end
end
