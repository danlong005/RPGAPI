#!/usr/bin/env python3
"""Builds docs/index.html, the API reference with a sidebar, from
ApiDocumentation.md. Run it after changing the Markdown:

    python3 docs/build.py

With --wiki and a clone of the repository's wiki, it writes the reference
there too, as wiki pages (Home, Application, Request, ...) with a _Sidebar
that GitHub shows beside every page; commit and push the wiki after it:

    python3 docs/build.py --wiki ../RPGAPI.wiki

It needs only Python 3's standard library. The Markdown it reads is the
subset ApiDocumentation.md uses: headings, paragraphs, nested lists, tables,
fenced code, <details> blocks, inline code, bold and links. Ids follow
GitHub's rules, so #rpgapi_setcookie links work on both. Links to other files
of the repository go to them on GitHub."""
import html
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SOURCE = os.path.join(HERE, '..', 'ApiDocumentation.md')
TARGET = os.path.join(HERE, 'index.html')
REPOSITORY = 'https://github.com/danlong005/RPGAPI'


def slug(text):
    """The id GitHub gives a heading."""
    text = re.sub(r'<[^>]+>', '', text)
    text = text.strip().lower()
    text = re.sub(r'[^\w\- ]', '', text)
    return text.replace(' ', '-')


def link_target(url):
    if url.startswith(('#', 'http://', 'https://', 'mailto:')):
        return url
    if url.startswith('ApiDocumentation.md#'):
        return url[len('ApiDocumentation.md'):]
    return f'{REPOSITORY}/blob/main/{url}'


def inline(text):
    """Inline Markdown: `code`, **bold**, [links](url); the rest escaped. Code
    spans are set aside first, so bold text and links can hold code."""
    spans = []

    def keep(match):
        code = match.group(2)
        if match.group(1) == '``':
            code = code.strip()
        spans.append(f'<code>{html.escape(code, quote=False)}</code>')
        return f'\x00{len(spans) - 1}\x00'

    text = re.sub(r'(``?)(.+?)\1', keep, text)
    text = html.escape(text, quote=False)
    text = re.sub(r'\*\*(.+?)\*\*', r'<strong>\1</strong>', text)
    text = re.sub(r'\[([^\]]+)\]\(([^)\s]+)\)',
                  lambda m: f'<a href="{html.escape(link_target(m.group(2)))}">{m.group(1)}</a>',
                  text)
    return re.sub('\x00(\\d+)\x00', lambda m: spans[int(m.group(1))], text)


def indent_of(line):
    return len(line) - len(line.lstrip(' '))


def blocks(lines):
    """Markdown lines to HTML."""
    out = []
    index = 0
    while index < len(lines):
        line = lines[index]
        stripped = line.strip()
        if stripped == '':
            index += 1
        elif stripped.startswith('```'):
            language = stripped[3:].strip()
            index += 1
            code = []
            while index < len(lines) and not lines[index].strip().startswith('```'):
                code.append(lines[index])
                index += 1
            index += 1
            margin = min((indent_of(c) for c in code if c.strip()), default=0)
            code = '\n'.join(c[margin:] for c in code)
            label = f' data-language="{language}"' if language else ''
            out.append(f'<pre{label}><code>{html.escape(code, quote=False)}</code></pre>')
        elif re.match(r'#{1,6} ', stripped):
            level = len(stripped) - len(stripped.lstrip('#'))
            text = stripped[level:].strip()
            out.append(f'<h{level} id="{slug(text)}">{inline(text)}</h{level}>')
            index += 1
        elif stripped == '---':
            out.append('<hr>')
            index += 1
        elif stripped.startswith('<details') or stripped.startswith('</details'):
            summary = re.match(r'<details><summary>(.*)</summary>', stripped)
            if summary:
                out.append(f'<details><summary>{inline(summary.group(1))}</summary>')
            else:
                out.append(stripped)
            index += 1
        elif stripped.startswith('|') and index + 1 < len(lines) and \
                re.match(r'\s*\|[\s:\-|]+\|\s*$', lines[index + 1]):
            rows = []
            while index < len(lines) and lines[index].strip().startswith('|'):
                rows.append(lines[index].strip())
                index += 1
            out.append(table(rows))
        elif re.match(r'\s*- ', line):
            index = listing(lines, index, out)
        else:
            paragraph = []
            while index < len(lines) and lines[index].strip() and \
                    not lines[index].strip().startswith(('```', '|', '<details', '</details')) and \
                    not re.match(r'\s*#{1,6} ', lines[index]) and \
                    not re.match(r'\s*- ', lines[index]):
                paragraph.append(lines[index].strip())
                index += 1
            out.append(f'<p>{inline(" ".join(paragraph))}</p>')
    return '\n'.join(out)


def listing(lines, index, out):
    """A list starting at lines[index]; its items can hold paragraphs, lists
    and code. Returns the index after it."""
    base = indent_of(lines[index])
    items = []
    while index < len(lines):
        line = lines[index]
        if re.match(r'\s*- ', line) and indent_of(line) == base:
            items.append([line[base + 2:]])
            index += 1
        elif line.strip() == '':
            # a blank line ends the list unless the next line belongs to it
            following = index + 1
            if following < len(lines) and lines[following].strip() and \
                    indent_of(lines[following]) > base:
                items[-1].append('')
                index += 1
            else:
                break
        elif indent_of(line) > base:
            items[-1].append(line[min(indent_of(line), base + 2):])
            index += 1
        else:
            break
    out.append('<ul>')
    for item in items:
        content = blocks(item)
        # a single paragraph needs no <p>
        if content.count('<p>') == 1 and content.startswith('<p>') and '\n' not in content:
            content = content[3:-4]
        out.append(f'<li>{content}</li>')
    out.append('</ul>')
    return index


def table(rows):
    def cells(row):
        # | a | b `x | y` | : split on pipes outside code
        parts, current, in_code = [], '', False
        for character in row.strip().strip('|'):
            if character == '`':
                in_code = not in_code
            if character == '|' and not in_code:
                parts.append(current)
                current = ''
            else:
                current += character
        parts.append(current)
        return [p.strip() for p in parts]
    head = cells(rows[0])
    body = [cells(r) for r in rows[2:]]
    out = ['<div class="table"><table><thead><tr>']
    out += [f'<th>{inline(h)}</th>' for h in head]
    out.append('</tr></thead><tbody>')
    for row in body:
        out.append('<tr>' + ''.join(f'<td>{inline(c)}</td>' for c in row) + '</tr>')
    out.append('</tbody></table></div>')
    return ''.join(out)


def sidebar(lines):
    """The navigation: each ## a group, each ### in it an entry. The page's
    own contents list is left out; the sidebar is that list."""
    groups = []
    in_code = False
    for line in lines:
        if line.strip().startswith('```'):
            in_code = not in_code
        if in_code:
            continue
        if line.startswith('## ') and line[3:].strip() != 'Contents':
            groups.append((line[3:].strip(), []))
        elif line.startswith('### ') and groups:
            groups[-1][1].append(line[4:].strip())
    out = []
    for title, entries in groups:
        out.append(f'<div class="group"><a class="group-title" href="#{slug(title)}">'
                   f'{inline(title)}</a><ul>')
        for entry in entries:
            out.append(f'<li><a href="#{slug(entry)}">{inline(entry)}</a></li>')
        out.append('</ul></div>')
    return '\n'.join(out)


def without_contents(lines):
    """The Markdown without its ## Contents section."""
    out, skipping = [], False
    for line in lines:
        if line.startswith('## '):
            skipping = line[3:].strip() == 'Contents'
        if not skipping:
            out.append(line)
    return out


def wiki(lines, directory):
    """The reference as wiki pages: one for each ## section (the text before
    the first, and Getting started, go on Home), a _Sidebar listing every
    entry, and a _Footer. Links to entries on other pages are made to point
    there, and links to files of the repository to GitHub."""
    pages = [('Home', [])]
    in_code = False
    for line in without_contents(lines[1:]):
        if line.strip().startswith('```'):
            in_code = not in_code
        if not in_code and line.startswith('## ') and line[3:].strip() != 'Getting started':
            pages.append((line[3:].strip().replace(' ', '-'), []))
            continue
        pages[-1][1].append(line)

        # which page each heading's anchor is on
    anchor_page = {}
    for name, body in pages:
        anchor_page[slug(name.replace('-', ' '))] = name
        in_code = False
        for line in body:
            if line.strip().startswith('```'):
                in_code = not in_code
            if not in_code and re.match(r'#{2,6} ', line):
                anchor_page[slug(line.lstrip('#').strip())] = name

    def target(url, page):
        if url.startswith('ApiDocumentation.md#'):
            url = url[len('ApiDocumentation.md'):]
        if url.startswith('#'):
            anchor = url[1:]
            where = anchor_page.get(anchor, page)
            if where != page and slug(where.replace('-', ' ')) == anchor:
                return where
            return url if where == page else f'{where}{url}'
        if url.startswith(('http://', 'https://', 'mailto:')):
            return url
        if url == 'ApiDocumentation.md':
            return 'Home'
        return f'{REPOSITORY}/blob/main/{url}'

    def fix_links(text, page):
        return re.sub(r'\]\(([^)\s]+)\)', lambda m: f']({target(m.group(1), page)})', text)

    os.makedirs(directory, exist_ok=True)
    for name, body in pages:
        out = []
        in_code = False
        for line in body:
            if line.strip().startswith('```'):
                in_code = not in_code
            elif not in_code:
                if line.strip() == '---':
                    continue
                    # the page's name is its title: its entries one level up
                if re.match(r'#{3,6} ', line) and name != 'Home':
                    line = line[1:]
                line = fix_links(line, name)
            out.append(line)
        text = '\n'.join(out).strip('\n') + '\n'
        if name == 'Home':
            text = (lines[0].lstrip('# ').strip() + '\n\n').replace('RPGAPI API reference\n\n', '') + text
        with open(os.path.join(directory, name + '.md'), 'w', encoding='utf-8', newline='\n') as file:
            file.write(text)

    sidebar_lines = ['**[RPGAPI API reference](Home)**', '']
    in_code = False
    for name, body in pages:
        entries = []
        for line in body:
            if line.strip().startswith('```'):
                in_code = not in_code
            if not in_code and line.startswith('### '):
                entries.append(line[4:].strip())
        title = name.replace('-', ' ')
        if name == 'Home':
            sidebar_lines.append('**[Getting started](Home#getting-started)**')
        else:
            sidebar_lines.append(f'**[{title}]({name})**')
        for entry in entries:
            sidebar_lines.append(f'- [{entry}]({name}#{slug(entry)})')
        sidebar_lines.append('')
    with open(os.path.join(directory, '_Sidebar.md'), 'w', encoding='utf-8', newline='\n') as file:
        file.write('\n'.join(sidebar_lines))
    with open(os.path.join(directory, '_Footer.md'), 'w', encoding='utf-8', newline='\n') as file:
        file.write(f'Generated from [ApiDocumentation.md]({REPOSITORY}/blob/main/ApiDocumentation.md) '
                   f'by `docs/build.py`: change it there, not here. '
                   f'Also as a [web page with a sidebar]({REPOSITORY}/blob/main/docs/index.html).\n')
    print(f'wrote {len(pages)} pages, _Sidebar and _Footer to {directory}')


def main():
    with open(SOURCE, encoding='utf-8') as file:
        lines = file.read().replace('\r\n', '\n').split('\n')
    title = lines[0].lstrip('# ').strip()
    body = blocks(without_contents(lines[1:]))
    page = TEMPLATE.replace('{{title}}', html.escape(title)) \
                   .replace('{{sidebar}}', sidebar(lines)) \
                   .replace('{{body}}', body) \
                   .replace('{{repository}}', REPOSITORY)
    with open(TARGET, 'w', encoding='utf-8', newline='\n') as file:
        file.write(page)
    print(f'wrote {os.path.relpath(TARGET)}')
    if len(sys.argv) >= 3 and sys.argv[1] == '--wiki':
        wiki(lines, sys.argv[2])


TEMPLATE = r'''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>{{title}}</title>
<!-- generated from ApiDocumentation.md by docs/build.py: change the Markdown
     and run it again rather than changing this file -->
<style>
:root {
  --bg: #ffffff; --fg: #1f2328; --muted: #59636e; --line: #d1d9e0;
  --side: #f6f8fa; --code-bg: #f3f4f6; --pre-bg: #f6f8fa; --accent: #0969da;
  --accent-bg: #ddf4ff; --mark: #fff8c5;
}
@media (prefers-color-scheme: dark) {
  :root:not([data-theme="light"]) {
    --bg: #0d1117; --fg: #e6edf3; --muted: #9198a1; --line: #30363d;
    --side: #010409; --code-bg: #262c36; --pre-bg: #151b23; --accent: #4493f8;
    --accent-bg: #121d2f; --mark: #3b2e0a;
    color-scheme: dark;
  }
}
:root[data-theme="dark"] {
  --bg: #0d1117; --fg: #e6edf3; --muted: #9198a1; --line: #30363d;
  --side: #010409; --code-bg: #262c36; --pre-bg: #151b23; --accent: #4493f8;
  --accent-bg: #121d2f; --mark: #3b2e0a;
  color-scheme: dark;
}
* { box-sizing: border-box; }
html { scroll-padding-top: 1rem; }
body {
  margin: 0; background: var(--bg); color: var(--fg);
  font: 16px/1.6 -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
}
a { color: var(--accent); text-decoration: none; }
a:hover { text-decoration: underline; }
code, pre { font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; font-size: 0.875em; }
code { background: var(--code-bg); padding: 0.1em 0.35em; border-radius: 4px; }
pre {
  background: var(--pre-bg); border: 1px solid var(--line); border-radius: 6px;
  padding: 0.9rem 1rem; overflow-x: auto; line-height: 1.45;
}
pre code { background: none; padding: 0; font-size: 1em; }

.side {
  position: fixed; top: 0; bottom: 0; left: 0; width: 290px;
  background: var(--side); border-right: 1px solid var(--line);
  display: flex; flex-direction: column;
}
.side-head { padding: calc(1.1rem + env(safe-area-inset-top, 0px)) 1rem 0.75rem; border-bottom: 1px solid var(--line); }
.side-head .name { font-weight: 700; font-size: 1.15rem; color: var(--fg); }
.side-head .links { font-size: 0.85rem; margin-top: 0.2rem; }
.side-head .links a { margin-right: 0.75rem; }
.search {
  width: 100%; margin-top: 0.75rem; padding: 0.45rem 0.6rem; font: inherit; font-size: 0.9rem;
  color: var(--fg); background: var(--bg); border: 1px solid var(--line); border-radius: 6px;
}
.nav { overflow-y: auto; padding: 0.5rem 0 calc(2rem + env(safe-area-inset-bottom, 0px)); flex: 1; }
.group { margin: 0.35rem 0; }
.group-title {
  display: block; padding: 0.3rem 1rem; font-weight: 600; font-size: 0.8rem;
  text-transform: uppercase; letter-spacing: 0.04em; color: var(--muted);
}
.nav ul { list-style: none; margin: 0; padding: 0; }
.nav li a {
  display: block; padding: 0.18rem 1rem 0.18rem 1.5rem; font-size: 0.86rem; color: var(--fg);
  border-left: 3px solid transparent; overflow-wrap: anywhere;
}
.nav li a:hover { background: var(--accent-bg); text-decoration: none; }
.nav li a.current { border-left-color: var(--accent); background: var(--accent-bg); color: var(--accent); }
.nav code { background: none; padding: 0; font-size: 0.95em; }
.nav .hidden { display: none; }

main { margin-left: 290px; padding: 1.5rem 3rem 5rem; max-width: 980px; }
h1 { font-size: 2rem; margin: 0.5rem 0 1rem; }
h2 { font-size: 1.6rem; margin: 2.5rem 0 1rem; padding-bottom: 0.3rem; border-bottom: 1px solid var(--line); }
h3 { font-size: 1.2rem; margin: 2.2rem 0 0.6rem; }
h3 code, h2 code { font-size: 0.95em; }
h2:target, h3:target { background: var(--mark); border-radius: 4px; }
hr { border: 0; border-top: 1px solid var(--line); margin: 2.5rem 0; }
.table { overflow-x: auto; margin: 1rem 0; }
table { border-collapse: collapse; font-size: 0.92rem; }
th, td { border: 1px solid var(--line); padding: 0.4rem 0.7rem; text-align: left; vertical-align: top; }
th { background: var(--side); }
details { margin: 0.75rem 0; }
summary { cursor: pointer; color: var(--muted); }
ul { padding-left: 1.4rem; }
li { margin: 0.2rem 0; }

.menu {
  display: none; position: fixed; top: calc(0.75rem + env(safe-area-inset-top, 0px)); right: 0.75rem; z-index: 3;
  padding: 0.4rem 0.75rem; font: inherit; font-size: 0.9rem; color: var(--fg);
  background: var(--side); border: 1px solid var(--line); border-radius: 6px;
}
.theme { background: none; border: 0; padding: 0; font: inherit; font-size: 0.85rem; color: var(--accent); cursor: pointer; }
@media (max-width: 860px) {
  .menu { display: block; }
  .side { transform: translateX(-100%); transition: transform 0.2s; z-index: 2; width: 85%; max-width: 320px; }
  body.open .side { transform: none; box-shadow: 0 0 0 100vmax rgba(0, 0, 0, 0.35); }
  main { margin-left: 0; padding: 3.5rem 1rem 4rem; }
}
</style>
</head>
<body>
<button class="menu" type="button" aria-controls="side" aria-expanded="false">Menu</button>
<aside class="side" id="side">
  <div class="side-head">
    <a class="name" href="#">RPGAPI</a>
    <div class="links">
      <a href="{{repository}}">GitHub</a>
      <a href="{{repository}}/blob/main/QuickStart.md">Quick Start</a>
      <a href="{{repository}}/tree/main/examples">Examples</a>
      <button class="theme" type="button">Theme</button>
    </div>
    <input class="search" type="search" placeholder="Filter, e.g. cookie" aria-label="Filter the contents">
  </div>
  <nav class="nav">
{{sidebar}}
  </nav>
</aside>
<main>
<h1>{{title}}</h1>
{{body}}
</main>
<script>
(function () {
  var nav = document.querySelector('.nav');
  var links = Array.prototype.slice.call(nav.querySelectorAll('li a'));

  // the filter: entries whose name has the text, and the groups holding them
  document.querySelector('.search').addEventListener('input', function (event) {
    var text = event.target.value.trim().toLowerCase();
    nav.querySelectorAll('.group').forEach(function (group) {
      var shown = 0;
      group.querySelectorAll('li').forEach(function (item) {
        var match = !text || item.textContent.toLowerCase().indexOf(text) >= 0 ||
                    group.querySelector('.group-title').textContent.toLowerCase().indexOf(text) >= 0;
        item.classList.toggle('hidden', !match);
        if (match) shown++;
      });
      group.classList.toggle('hidden', text && shown === 0);
    });
  });

  // the entry being read, marked in the sidebar
  var headings = links.map(function (link) {
    return document.getElementById(decodeURIComponent(link.hash.slice(1)));
  });
  var current = null;
  function mark() {
    var best = -1;
    for (var i = 0; i < headings.length; i++) {
      if (headings[i] && headings[i].getBoundingClientRect().top < 120) best = i;
    }
    var link = best >= 0 ? links[best] : null;
    if (link === current) return;
    if (current) current.classList.remove('current');
    current = link;
    if (current) {
      current.classList.add('current');
      var box = nav.getBoundingClientRect(), place = current.getBoundingClientRect();
      if (place.top < box.top || place.bottom > box.bottom) current.scrollIntoView({ block: 'nearest' });
    }
  }
  var waiting = false;
  window.addEventListener('scroll', function () {
    if (!waiting) { waiting = true; requestAnimationFrame(function () { waiting = false; mark(); }); }
  });
  mark();

  // the menu on narrow screens
  var menu = document.querySelector('.menu');
  menu.addEventListener('click', function () {
    var open = document.body.classList.toggle('open');
    menu.setAttribute('aria-expanded', open);
  });
  nav.addEventListener('click', function (event) {
    if (event.target.closest('a')) { document.body.classList.remove('open'); menu.setAttribute('aria-expanded', 'false'); }
  });

  // light or dark, remembered in this browser
  var root = document.documentElement;
  try { var saved = localStorage.getItem('rpgapi-theme'); if (saved) root.setAttribute('data-theme', saved); } catch (e) {}
  document.querySelector('.theme').addEventListener('click', function () {
    var dark = root.getAttribute('data-theme') === 'dark' ||
               (!root.getAttribute('data-theme') && matchMedia('(prefers-color-scheme: dark)').matches);
    root.setAttribute('data-theme', dark ? 'light' : 'dark');
    try { localStorage.setItem('rpgapi-theme', dark ? 'light' : 'dark'); } catch (e) {}
  });
})();
</script>
</body>
</html>
'''

if __name__ == '__main__':
    main()
