class Vte3 < Formula
  desc "Terminal emulator widget used by GNOME terminal"
  homepage "https://wiki.gnome.org/Apps/Terminal/VTE"
  url "https://download.gnome.org/sources/vte/0.70/vte-0.70.2.tar.xz"
  sha256 "4d15b4380de3f564d57eabd006389c407c705df5b0c70030fdcc24971a334d80"
  license "LGPL-2.0-or-later"
  revision 1

  bottle do
    sha256 arm64_ventura:  "eb57fde7e74efe6d97f791028d097d55ba00a5226526a95e72f2d4a7c3fc81aa"
    sha256 arm64_monterey: "4e7eb735689f2f0b583ef2da76125c32cc93f150e777c910f4b9347eee249b91"
    sha256 arm64_big_sur:  "0c5e8fb9555270b2309158bcd1d36f3b6ae7c37da4e7e490c9de9943542652f8"
    sha256 ventura:        "1b6bea826a7256dbd44d3d0de6cbeef078280aff9e308bfb48eba7b529db419c"
    sha256 monterey:       "6a2a1442d72544d7a10e252ac1c9673bb9fa4a096d0f3725e56671d2511cbf83"
    sha256 big_sur:        "217e5ae3fea4e1dcd2b0ed48f4624c4c84236f4a364f03e62759eacc402ba81c"
    sha256 x86_64_linux:   "b1ec1d73d262b8dc6a92d14da66b1889391079302fc45ea1dbb61562c0266d99"
  end

  depends_on "gobject-introspection" => :build
  depends_on "meson" => :build
  depends_on "ninja" => :build
  depends_on "pkg-config" => :build
  depends_on "vala" => :build
  depends_on "gettext"
  depends_on "gnutls"
  depends_on "gtk+3"
  depends_on "icu4c"
  depends_on macos: :mojave
  depends_on "pcre2"

  on_macos do
    depends_on "llvm" => [:build, :test] if DevelopmentTools.clang_build_version <= 1200
  end

  on_linux do
    depends_on "linux-headers@5.15" => :build
    depends_on "systemd"
  end

  fails_with :clang do
    build 1200
    cause "Requires C++20"
  end

  fails_with :gcc do
    version "9"
    cause "Requires C++20"
  end

  # submitted upstream as https://gitlab.gnome.org/tschoonj/vte/merge_requests/1
  patch :DATA

  def install
    ENV.llvm_clang if OS.mac? && (DevelopmentTools.clang_build_version <= 1200)
    ENV["XML_CATALOG_FILES"] = etc/"xml/catalog"

    # Work around for ../src/widget.cc:765:30: error: use of undeclared identifier 'W_EXITCODE'
    # Issue ref: https://gitlab.gnome.org/GNOME/vte/-/issues/2592
    # TODO: Remove once issue is fixed upstream.
    ENV.append_to_cflags "-D_DARWIN_C_SOURCE" if OS.mac?

    system "meson", *std_meson_args, "build",
                    "-Dgir=true",
                    "-Dgtk3=true",
                    "-Dgnutls=true",
                    "-Dvapi=true",
                    "-D_b_symbolic_functions=false"
    system "meson", "compile", "-C", "build", "--verbose"
    system "meson", "install", "-C", "build"
  end

  test do
    ENV.clang if OS.mac? && (DevelopmentTools.clang_build_version <= 1200)

    (testpath/"test.c").write <<~EOS
      #include <vte/vte.h>

      int main(int argc, char *argv[]) {
        guint v = vte_get_major_version();
        return 0;
      }
    EOS
    atk = Formula["atk"]
    cairo = Formula["cairo"]
    fontconfig = Formula["fontconfig"]
    freetype = Formula["freetype"]
    gdk_pixbuf = Formula["gdk-pixbuf"]
    gettext = Formula["gettext"]
    glib = Formula["glib"]
    gnutls = Formula["gnutls"]
    gtkx3 = Formula["gtk+3"]
    harfbuzz = Formula["harfbuzz"]
    libepoxy = Formula["libepoxy"]
    libpng = Formula["libpng"]
    libtasn1 = Formula["libtasn1"]
    nettle = Formula["nettle"]
    pango = Formula["pango"]
    pixman = Formula["pixman"]
    flags = %W[
      -I#{atk.opt_include}/atk-1.0
      -I#{cairo.opt_include}/cairo
      -I#{fontconfig.opt_include}
      -I#{freetype.opt_include}/freetype2
      -I#{gdk_pixbuf.opt_include}/gdk-pixbuf-2.0
      -I#{gettext.opt_include}
      -I#{glib.opt_include}/gio-unix-2.0/
      -I#{glib.opt_include}/glib-2.0
      -I#{glib.opt_lib}/glib-2.0/include
      -I#{gnutls.opt_include}
      -I#{gtkx3.opt_include}/gtk-3.0
      -I#{harfbuzz.opt_include}/harfbuzz
      -I#{include}/vte-2.91
      -I#{libepoxy.opt_include}
      -I#{libpng.opt_include}/libpng16
      -I#{libtasn1.opt_include}
      -I#{nettle.opt_include}
      -I#{pango.opt_include}/pango-1.0
      -I#{pixman.opt_include}/pixman-1
      -D_REENTRANT
      -L#{atk.opt_lib}
      -L#{cairo.opt_lib}
      -L#{gdk_pixbuf.opt_lib}
      -L#{gettext.opt_lib}
      -L#{glib.opt_lib}
      -L#{gnutls.opt_lib}
      -L#{gtkx3.opt_lib}
      -L#{lib}
      -L#{pango.opt_lib}
      -latk-1.0
      -lcairo
      -lcairo-gobject
      -lgdk-3
      -lgdk_pixbuf-2.0
      -lgio-2.0
      -lglib-2.0
      -lgnutls
      -lgobject-2.0
      -lgtk-3
      -lpango-1.0
      -lpangocairo-1.0
      -lvte-2.91
      -lz
    ]
    flags << "-lintl" if OS.mac?
    system ENV.cc, "test.c", "-o", "test", *flags
    system "./test"
  end
end

__END__
diff --git a/meson.build b/meson.build
index e2200a75..df98872f 100644
--- a/meson.build
+++ b/meson.build
@@ -78,6 +78,8 @@ lt_age = vte_minor_version * 100 + vte_micro_version - lt_revision
 lt_current = vte_major_version + lt_age

 libvte_gtk3_soversion = '@0@.@1@.@2@'.format(libvte_soversion, lt_current, lt_revision)
+osx_version_current = lt_current + 1
+libvte_gtk3_osxversions = [osx_version_current, '@0@.@1@.0'.format(osx_version_current, lt_revision)]
 libvte_gtk4_soversion = libvte_soversion.to_string()

 # i18n
diff --git a/src/meson.build b/src/meson.build
index 79d4a702..0495dea8 100644
--- a/src/meson.build
+++ b/src/meson.build
@@ -224,6 +224,7 @@ if get_option('gtk3')
     vte_gtk3_api_name,
     sources: libvte_gtk3_sources,
     version: libvte_gtk3_soversion,
+    darwin_versions: libvte_gtk3_osxversions,
     include_directories: incs,
     dependencies: libvte_gtk3_deps,
     cpp_args: libvte_gtk3_cppflags,
