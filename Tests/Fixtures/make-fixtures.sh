#!/bin/sh
# Builds the small EPUB files the tests read (see docs/TEST_CASES.md). Run it from anywhere:
#   sh Tests/Fixtures/make-fixtures.sh
# The .epub files it makes are committed too, so tests never need to run it.
set -eu

out="$(cd "$(dirname "$0")" && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# container.xml: tells a reader where the package file (content.opf) is. Same in every book.
container() {
    mkdir -p "$1/META-INF"
    cat > "$1/META-INF/container.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>
EOF
}

# A chapter file: one <p> per argument after the file name.
chapter() {
    file="$1"
    shift
    {
        echo '<?xml version="1.0" encoding="UTF-8"?>'
        echo '<html xmlns="http://www.w3.org/1999/xhtml"><head><title>Chapter</title></head><body>'
        for paragraph in "$@"; do
            echo "<p>$paragraph</p>"
        done
        echo '</body></html>'
    } > "$file"
}

# toc.ncx with one entry per chapter file: "Title|file" arguments.
toc() {
    file="$1"
    shift
    {
        echo '<?xml version="1.0" encoding="UTF-8"?>'
        echo '<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1"><navMap>'
        order=1
        for entry in "$@"; do
            echo "<navPoint id=\"nav$order\" playOrder=\"$order\"><navLabel><text>${entry%%|*}</text></navLabel><content src=\"${entry#*|}\"/></navPoint>"
            order=$((order + 1))
        done
        echo '</navMap></ncx>'
    } > "$file"
}

# A 1×1 PNG, for the cover books.
png() {
    echo 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFBQIAX8jx0gAAAABJRU5ErkJggg==' | base64 -D > "$1"
}

# Zips a book folder into an EPUB: "mimetype" first and uncompressed, as the format requires.
# Fixed file dates, so running this again makes the same bytes.
pack() {
    folder="$1"
    name="$2"
    printf 'application/epub+zip' > "$folder/mimetype"
    find "$folder" -exec touch -t 202601010000 {} +
    rm -f "$out/$name"
    (cd "$folder" && zip -X0q "$out/$name" mimetype && zip -X9rq "$out/$name" META-INF OEBPS)
}

# minimal.epub: 2 chapters × 3 paragraphs, title and author, no cover.
book="$work/minimal"
container "$book"
mkdir -p "$book/OEBPS"
cat > "$book/OEBPS/content.opf" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0" unique-identifier="id">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>Minimal Book</dc:title>
    <dc:creator>Test Author</dc:creator>
    <dc:identifier id="id">minimal</dc:identifier>
  </metadata>
  <manifest>
    <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
    <item id="ch1" href="ch1.xhtml" media-type="application/xhtml+xml"/>
    <item id="ch2" href="ch2.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine toc="ncx"><itemref idref="ch1"/><itemref idref="ch2"/></spine>
</package>
EOF
toc "$book/OEBPS/toc.ncx" "Chapter One|ch1.xhtml" "Chapter Two|ch2.xhtml"
chapter "$book/OEBPS/ch1.xhtml" \
    "Anna opened the door. The hall was dark and cold." \
    "Mr. Darcy bowed. She left the room without a word." \
    "Outside, the rain kept falling on the quiet street."
chapter "$book/OEBPS/ch2.xhtml" \
    "Morning came slowly over the hills." \
    "Anna found the letter under the old clock. It was addressed to her." \
    "She read it twice, then put it in the fire."
pack "$book" minimal.epub

# no-chapters.epub: a valid book whose only file has no text.
book="$work/no-chapters"
container "$book"
mkdir -p "$book/OEBPS"
cat > "$book/OEBPS/content.opf" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0" unique-identifier="id">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>Empty Book</dc:title>
    <dc:identifier id="id">no-chapters</dc:identifier>
  </metadata>
  <manifest><item id="ch1" href="ch1.xhtml" media-type="application/xhtml+xml"/></manifest>
  <spine><itemref idref="ch1"/></spine>
</package>
EOF
chapter "$book/OEBPS/ch1.xhtml"
pack "$book" no-chapters.epub

# no-metadata.epub: one chapter, no title and no author.
book="$work/no-metadata"
container "$book"
mkdir -p "$book/OEBPS"
cat > "$book/OEBPS/content.opf" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0" unique-identifier="id">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:identifier id="id">no-metadata</dc:identifier></metadata>
  <manifest><item id="ch1" href="ch1.xhtml" media-type="application/xhtml+xml"/></manifest>
  <spine><itemref idref="ch1"/></spine>
</package>
EOF
chapter "$book/OEBPS/ch1.xhtml" "A book with no title page."
pack "$book" no-metadata.epub

# epub2-cover.epub: cover named by the EPUB 2 <meta name="cover"> tag.
book="$work/epub2-cover"
container "$book"
mkdir -p "$book/OEBPS"
cat > "$book/OEBPS/content.opf" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0" unique-identifier="id">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>EPUB 2 Cover</dc:title>
    <dc:creator>Cover Author</dc:creator>
    <dc:identifier id="id">epub2-cover</dc:identifier>
    <meta name="cover" content="cover-image"/>
  </metadata>
  <manifest>
    <item id="cover-image" href="images/cover.png" media-type="image/png"/>
    <item id="ch1" href="ch1.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine><itemref idref="ch1"/></spine>
</package>
EOF
mkdir -p "$book/OEBPS/images"
png "$book/OEBPS/images/cover.png"
chapter "$book/OEBPS/ch1.xhtml" "A book with an EPUB 2 cover."
pack "$book" epub2-cover.epub

# epub3-cover.epub: cover marked by the EPUB 3 properties="cover-image".
book="$work/epub3-cover"
container "$book"
mkdir -p "$book/OEBPS"
cat > "$book/OEBPS/content.opf" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="id">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>EPUB 3 Cover</dc:title>
    <dc:creator>Cover Author</dc:creator>
    <dc:identifier id="id">epub3-cover</dc:identifier>
  </metadata>
  <manifest>
    <item id="img" href="cover.png" media-type="image/png" properties="cover-image"/>
    <item id="ch1" href="ch1.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine><itemref idref="ch1"/></spine>
</package>
EOF
png "$book/OEBPS/cover.png"
chapter "$book/OEBPS/ch1.xhtml" "A book with an EPUB 3 cover."
pack "$book" epub3-cover.epub

# corrupt.epub: the first half of minimal.epub, like a download that stopped part way.
size=$(wc -c < "$out/minimal.epub")
head -c $((size / 2)) "$out/minimal.epub" > "$out/corrupt.epub"

echo "Made the fixtures in $out"
