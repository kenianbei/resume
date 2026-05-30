# Resume

## Installation

```bash
git clone https://github.com/kenianbei/resume.git
cd resume
```

## Build

```bash
docker build -t md2pdf .
```

## Usage

Replace or edit the resume.md and cover.md files with your own versions and run the following commands:

```bash
# Generate resume.
docker run --rm -v "`pwd`:/work" md2pdf resume.md resume.pdf

# Generate cover letter.
docker run --rm -v "`pwd`:/work" md2pdf cover.md cover.pdf
```
