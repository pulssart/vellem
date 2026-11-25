"""Render the French and English GitHub Pages site. Run with Python 3."""
import json
from html import escape
from pathlib import Path
from string import Template
from xml.etree import ElementTree

ROOT = Path(__file__).resolve().parents[1]
SITE = ROOT / "docs"
SOURCE = ROOT / "website"
PROJECTS = [
    ("sortie", "personal", "family-outing", "folder.personal"),
    ("devis", "personal", "home-quotes", "folder.personal"),
    ("design", "work", "design-review", "folder.product"),
]
catalog = json.loads((ROOT / "Vellem/Prompts.xcstrings").read_text())["strings"]
languages = json.loads((SOURCE / "carnet.json").read_text())
page = Template((SOURCE / "landing.html").read_text())
dmg = ElementTree.parse(ROOT / "appcast.xml").find("./channel/item/enclosure").attrib["url"]

def localized(lang, key):
    return catalog[key]["localizations"][lang]["stringUnit"]["value"]


for lang, content in languages.items():
    assets = ("../" if lang == "en" else "") + "assets/carnet/"
    values = {key: escape(value) for key, value in content.items() if isinstance(value, str)}
    cards, examples = [], []
    for slug, category, key, folder in PROJECTS:
        project = content["items"][slug]
        title = project["title"]
        request = project["request"]
        result = project["result"]
        prompt = "\n\n".join([
            request,
            localized(lang, key + ".instructions"),
            localized(lang, "sources"),
            localized(lang, "delivery").replace("%@", localized(lang, folder)),
        ])
        cards.append(f'''        <a class="card" data-category="{category}" href="#{slug}" aria-controls="{slug}">
          <img src="{assets}{slug}.webp" width="360" height="516" alt="">
          <span class="card-title">{escape(title)}</span>
        </a>''')
        bullets = "".join(f"<li>{escape(line)}</li>" for line in project["lines"])
        examples.append(f'''      <section class="example" id="{slug}" tabindex="-1" aria-labelledby="result-{slug}">
        <div class="request">
          <h2>{values["request"]}</h2>
          <p class="quotation">{escape(request)}</p>
          <button type="button" class="copy" hidden>
            <svg viewBox="0 0 24 24" aria-hidden="true"><rect x="7" y="3" width="14" height="15" rx="2"/><rect x="3" y="7" width="14" height="15" rx="2"/></svg>
            <span>{values["copy"]}</span>
          </button>
          <details class="prompt-text"><summary>{values["copy"]}</summary><pre>{escape(prompt)}</pre></details>
          <span class="sr-only" role="status"></span>
        </div>
        <div class="result">
          <h2>{values["result"]}</h2>
          <h3 id="result-{slug}">{escape(result)}</h3>
          <ul>{bullets}</ul>
          <a class="back" href="#projects">{values["all_projects"]} ↑</a>
        </div>
      </section>''')
    output = SITE / ("en/index.html" if lang == "en" else "index.html")
    output.parent.mkdir(parents=True, exist_ok=True)
    for key in ("headline", "intro"):
        values[key] = values[key].replace("\n", " <br>")
    text = page.substitute(values, lang=lang, dmg=escape(dmg), assets=assets,
                           canonical="https://pulssart.github.io/vellem/" + ("en/" if lang == "en" else ""),
                           other_url="../" if lang == "en" else "en/", other_lang="fr" if lang == "en" else "en",
                           gallery="\n".join(cards), examples="\n".join(examples))
    output.write_text(text)
