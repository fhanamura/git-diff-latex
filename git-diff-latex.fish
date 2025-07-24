#!/usr/bin/env fish

function header; set_color cyan; echo -e "\n🔷 $argv"; set_color normal; end
function info; set_color green; echo -e "✅ $argv"; set_color normal; end
function step; set_color blue; echo -e "➡️  $argv"; set_color normal; end
function warn; set_color yellow; echo -e "⚠️  $argv"; set_color normal; end
function error; set_color red; echo -e "❌ $argv"; set_color normal; end

# === Parse Arguments ===
set revision HEAD
set mainfile ""

for i in (seq (count $argv))
    switch $argv[$i]
        case "--revision=*"
            set revision (string replace -- "--revision=" "" $argv[$i])
        case "--help" "-h"
            echo "📘 Usage: git-diff-latex [--revision=REV] main.tex"
            exit 0
        case "*.tex"
            set mainfile $argv[$i]
    end
end

if test -z "$mainfile"
    error "No .tex file specified"
    echo "📘 Usage: git-diff-latex [--revision=REV] main.tex"
    exit 1
end

if not test -f $mainfile
    error "File '$mainfile' not found"
    exit 1
end

# === Setup ===
set mainbase (string replace ".tex" "" (basename $mainfile))
set gitroot (git rev-parse --show-toplevel)
set mainrel (realpath --relative-to=$gitroot $mainfile)

# Create temp working dir in project
set tempdir "./.git-diff-latex-temp"
command rm -rf $tempdir
mkdir -p $tempdir

set oldtree "$tempdir/old"
set newtree "$tempdir/new"
mkdir -p $oldtree $newtree

set oldflat "$tempdir/$mainbase"_old_flat.tex
set newflat "$tempdir/$mainbase"_new_flat.tex
set difffile "$tempdir/$mainbase"_diff.tex
set pdffile "$tempdir/$mainbase"_diff.pdf

# === Step 1: Git archive extraction ===
header "Step 1: Extracting snapshot from '$revision'"
step "Creating temp folder: $oldtree"
git.exe archive --format=tar $revision | tar -xf - -C $oldtree

# === Step 2: Flatten both versions ===
header "Step 2: Flattening LaTeX files with latexpand"

if not type -q latexpand.exe
    error "'latexpand.exe' not found — please install it via tlmgr"
    exit 1
end

step "Flattening OLD version from Git"
latexpand.exe --expand-usepackage "$mainrel" > "$oldflat"

step "Flattening CURRENT working version"
latexpand.exe --expand-usepackage "$mainfile" > $newflat

info "LaTeX files successfully flattened"

# === Step 3: Run latexdiff ===
header "Step 3: Running latexdiff"

if not type -q latexdiff.exe
    error "'latexdiff.exe' not found"
    exit 1
end

step "Comparing: $oldflat ⟶ $newflat"
latexdiff.exe $oldflat $newflat > $difffile
info "latexdiff completed"

# === Step 4: Compile PDF ===
header "Step 4: Compiling PDF with pdflatex"

if not type -q pdflatex.exe
    error "'pdflatex.exe' not found"
    exit 1
end

step "Running pdflatex (1st pass)"
pdflatex.exe -interaction=nonstopmode -output-directory $tempdir $difffile > /dev/null

step "Running pdflatex (2nd pass)"
pdflatex.exe -interaction=nonstopmode -output-directory $tempdir $difffile > /dev/null

# === Step 5: Finalize output ===
header "🎉 Final Output"

set finaltex "$mainbase"_diff.tex
set finalpdf "$mainbase"_diff.pdf

if test -e "$pdffile"
    mv "$pdffile" "$finalpdf"
    info "PDF generated: 📄 $finalpdf"
else
    error "PDF not generated"
end

if test -e "$difffile"
    mv "$difffile" "$finaltex"
    info "LaTeX diff saved: 📜 $finaltex"
else
    warn "No LaTeX diff output found"
end

# === Optional: Clean up temp folder ===
command rm -rf $tempdir
info "🧹 Temporary files removed"
