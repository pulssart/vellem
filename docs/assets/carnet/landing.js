"use strict";

const gallery = document.querySelector(".gallery");
const cards = [...gallery.querySelectorAll(".card")];
const filters = document.querySelector(".filters");
const filterButtons = [...filters.querySelectorAll("button")];
const examples = [...document.querySelectorAll(".example")];
const labels = document.querySelector(".examples").dataset;
let selected = cards[0];

function select(card) {
  selected = card;
  for (const item of cards) {
    if (item === card) item.setAttribute("aria-current", "true");
    else item.removeAttribute("aria-current");
  }
  for (const example of examples) example.hidden = "#" + example.id !== card.hash;
}

function filterBy(category) {
  for (const button of filterButtons) {
    button.setAttribute("aria-pressed", String(button.dataset.filter === category));
  }
  for (const card of cards) card.hidden = category !== "all" && card.dataset.category !== category;
  const visible = cards.filter(card => !card.hidden);
  gallery.toggleAttribute("data-limited", category !== "all");
  gallery.style.setProperty("--columns", visible.length);
  if (selected.hidden) {
    select(visible[0]);
    if (cards.some(card => card.hash === location.hash)) history.replaceState(null, "", selected.hash);
  }
  gallery.scrollLeft = 0;
}

function restoreProject() {
  const card = cards.find(item => item.hash === location.hash);
  if (card?.hidden) filterBy("all");
  select(card || selected);
}

for (const button of filterButtons) {
  button.addEventListener("click", () => filterBy(button.dataset.filter));
}
filters.hidden = false;
for (const card of cards) {
  card.addEventListener("click", event => {
    if (event.metaKey || event.ctrlKey || event.altKey || event.shiftKey) return;
    event.preventDefault();
    select(card);
    history.replaceState(null, "", card.hash);
    if (matchMedia("(max-width: 760px)").matches) {
      const panel = document.getElementById(card.hash.slice(1));
      panel.focus({preventScroll: true});
      panel.scrollIntoView({block: "start"});
    }
  });
}
window.addEventListener("hashchange", restoreProject);
restoreProject();

for (const example of examples) {
  const button = example.querySelector(".copy");
  const caption = button.querySelector("span");
  const original = caption.textContent;
  const status = example.querySelector("[role=status]");
  const details = example.querySelector(".prompt-text");
  const pre = details.querySelector("pre");
  let reset;
  button.hidden = false;
  details.hidden = true;
  button.addEventListener("click", async () => {
    try {
      await navigator.clipboard.writeText(pre.textContent);
      clearTimeout(reset);
      caption.textContent = labels.copied;
      status.textContent = labels.copied;
      reset = setTimeout(() => {
        caption.textContent = original;
        status.textContent = "";
      }, 2200);
    } catch {
      details.hidden = false;
      details.open = true;
      const range = document.createRange();
      range.selectNodeContents(pre);
      const selection = window.getSelection();
      selection.removeAllRanges();
      selection.addRange(range);
      details.querySelector("summary").textContent = labels.manual;
      status.textContent = labels.manual;
    }
  });
}

// Keep the signed DMG from the published feed as the offline or rate-limited fallback.
async function refreshDownload() {
  try {
    const response = await fetch("https://api.github.com/repos/pulssart/vellem/releases/latest", {referrerPolicy:"no-referrer"});
    if (!response.ok) return;
    const release = await response.json();
    const dmg = release.assets.find(asset =>
      /^https:\/\/github\.com\/pulssart\/vellem\/releases\/download\/[^/]+\/[^/]+\.dmg$/i.test(asset.browser_download_url));
    if (dmg) document.querySelector("[data-download]").href = dmg.browser_download_url;
  } catch {
    // The initial download link works without JavaScript or a GitHub API response.
  }
}
refreshDownload();
