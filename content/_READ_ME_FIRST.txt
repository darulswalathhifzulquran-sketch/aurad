BULK IMPORT - HOW IT WORKS
==========================

Put your files in the folders below. This "content" folder sits next to
pubspec.yaml, i.e.  Downloads\al_auradu\al_auradu\content\
Sub-folders at any depth are scanned.

  content/
    quran/            surah files - start the name with the surah number:
                        001-fatiha.txt   002-baqarah.docx   114-an-nas.md
    quran/juz/        juz-01.txt ... juz-30.txt
    mawlid/  baith/  mala/  swalath/  dua/  ratib/
    aurad/  manaqib/  (created automatically)
    any-other-name/   a NEW category is created from the folder name

Folders/files that start with "_" or "." are ignored (like this file).

FILE TYPES YOU CAN SAVE
-----------------------
.docx  Word.        Normal paragraphs; a 2-column Word table becomes the bordered
                    table; Ctrl+Enter (page break) = page break.
.pptx  PowerPoint.  Text boxes and 2-column tables on every slide are read,
                    slide after slide. Pictures are ignored (listed as a warning).
.txt   Notepad.     Save As -> Encoding: UTF-8.
.md    Markdown.    2-column tables, "# Title", "---" page break.
.json  One item / list of items / whole library.

NOT READ: .pdf  .doc  .ppt (old formats)  pictures.
  .doc/.ppt -> open in Word/PowerPoint and Save As .docx/.pptx
  .pdf      -> copy the text out into Word (check Arabic carefully) and save .docx

TITLE AND CATEGORY (optional)
-----------------------------
Put these lines at the very TOP of the file (works in Word, PowerPoint, txt, md):
    @title: Mankoos Mawlid
    @ar: مولد منقوص
    @category: mawlid
Without them: the file name is the title and the folder is the category.

PAGES
-----
Text flows from page to page so that every page is filled - nothing is left
blank at the bottom. (Write  @flow: false  at the top to keep your own page
breaks instead.) The app picks the font size itself.

HOW TO RUN
----------
Double-click  import_all.bat  (preview -> press Y -> imported), or:
    dart tool/import_content.dart --dry-run
    dart tool/import_content.dart
Then:  flutter run -d chrome   (or press R)

SAFETY
------
* never deletes or overwrites an item that already has content
* never imports the same text twice
* cancels a file (listed as an error) if any Arabic/Malayalam/English letter
  would be lost
* backs up library.json first: content/_import/backups/
* report: content/_import/import_report.txt
