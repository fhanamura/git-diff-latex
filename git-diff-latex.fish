#!/usr/bin/env fish

# === Parse Arguments ===
set revision HEAD
set mainfile ""

for i in (seq (count $argv))
    switch $argv[$i]
        case "--revision=*"
            set revision (string replace -- "--revision=" "" $argv[$i])
        case "--help" "-h"
            echo "Usage: git-diff-latex [--revision=REV] main.tex"
            exit 0
        case "*.tex"
            set mainfile $argv[$i]
    end
end

# === Validate ===
if test -z "$mainfile"
    echo "❌ Error: no main.tex file specified"
    echo "Usage: git-diff-latex [--revision=REV] main.tex"
    exit 1
end

if not test -f $mainfile
    echo "❌ Error: file '$mainfile' not found"
    exit 1
end

# === Define intermediate files ===
set base (string replace ".tex" "" $mainfile)
set oldfile $base"_old.tex"
set newfile $base"_new.tex"
set oldflat $base"_old_flat.tex"
set newflat $base"_new_flat.tex"
set difffile $base"_diff.tex"
set pdffile $base"_diff.pdf"

# === STEP 1: Extract old version from Git ===
echo "🔁 Extracting $mainfile from $revision..."
git show $revision:$mainfile > $oldfile

# === STEP 2: Copy current version ===
echo "📄 Copying current version..."
cp $mainfile $newfile

# === STEP 3: Optional flattening ===
if type -q latexexpand
    echo "📦 Flattening files with latexexpand..."
    latexexpand $oldfile > $oldflat
    latexexpand $newfile > $newflat
    set oldfile $oldflat
    set newfile $newflat
else
    echo "⚠️  'latexexpand' not found. Proceeding without flattening."
end

# === STEP 4: Run latexdiff ===
echo "📊 Running latexdiff..."
latexdiff $oldfile $newfile > $difffile

# === STEP 5: Compile diff ===
echo "📄 Compiling to PDF..."
pdflatex $difffile > /dev/null
pdflatex $difffile > /dev/null

# === Done ===
if test -e $pdffile
    echo "✅ Done: $pdffile generated."
else
    echo "❌ Failed to generate PDF."
end
