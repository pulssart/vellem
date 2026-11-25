'use strict';

const markdown = window.markdownit({ html: true, linkify: true }).use(window.markdownitFootnote);
markdown.use(texmath, { engine: katex, delimiters: ['brackets', 'dollars'] });
for (const name of ['math_inline', 'math_inline_double', 'math_block', 'math_block_eqno']) {
    markdown.renderer.rules[name] = (tokens, index) => {
        const tag = name.startsWith('math_block') ? 'div' : 'span';
        const token = tokens[index];
        const number = token.info ? ' (' + markdown.utils.escapeHtml(token.info) + ')' : '';
        return '<' + tag + ' class="formula">' + markdown.utils.escapeHtml(token.content) + '</' + tag + '>' + number;
    };
}
const originalValidate = markdown.validateLink;
markdown.validateLink = url => originalValidate(url) || url.startsWith('file:///');
for (const tag of ['th_open', 'td_open']) {
    markdown.renderer.rules[tag] = (tokens, index, options, env, renderer) => {
        const alignment = tokens[index].attrGet('style')?.match(/^text-align:(left|center|right)$/);
        if (alignment) tokens[index].attrSet('align', alignment[1]);
        return renderer.renderToken(tokens, index, options);
    };
}

const allowedTags = ('p br div span strong b em i del s u mark small sub sup kbd samp var abbr ' +
    'h1 h2 h3 h4 h5 h6 ul ol li dl dt dd blockquote hr pre code ' +
    'a img figure figcaption table caption thead tbody tfoot tr td th ' +
    'section article aside details summary time').split(' ');
const allowedAttributes = ('alt href src title id class colspan rowspan start value scope align open lang dir').split(' ');

function imageURL(value) {
    if (/^https:\/\//i.test(value) || /^data:image\/(?:png|jpeg|gif|webp|avif);base64,/i.test(value)) return value;
    if (!value || value.startsWith('//')) return null;
    try {
        const url = new URL(value, 'file:///');
        if (url.protocol !== 'file:' || url.host) return null;
        const path = /^[a-z]+:/i.test(value) || value.startsWith('/') ? decodeURIComponent(url.pathname) : decodeURIComponent(value);
        return 'vellem-image://attachment/?path=' + encodeURIComponent(path);
    } catch { return null; }
}

DOMPurify.addHook('uponSanitizeAttribute', (node, attribute) => {
    if (attribute.attrName !== 'src') return;
    const url = node.nodeName === 'IMG' && imageURL(attribute.attrValue);
    if (url) attribute.attrValue = url;
    else attribute.keepAttr = false;
});

function richContent(source) {
    const isHTMLDocument = /^\s*(?:<!doctype html\b|<html[\s>])/i.test(source);
    const fragment = DOMPurify.sanitize(isHTMLDocument ? source : markdown.render(source), {
        RETURN_DOM_FRAGMENT: true,
        ALLOWED_TAGS: allowedTags, ALLOWED_ATTR: allowedAttributes,
        ALLOW_DATA_ATTR: false, ALLOW_ARIA_ATTR: false, ADD_URI_SAFE_ATTR: ['src']
    });
    for (const element of fragment.querySelectorAll('[class]')) {
        const formula = element.matches('span.formula, div.formula');
        const language = element.tagName === 'CODE' && [...element.classList].find(name => /^language-[\w+#.-]+$/.test(name));
        element.removeAttribute('class');
        if (language) element.classList.add(language);
        if (formula) {
            const source = element.textContent;
            element.className = 'formula';
            try {
                katex.render(source, element, { displayMode: element.tagName === 'DIV', output: 'mathml',
                    trust: false, maxSize: 10, maxExpand: 500, throwOnError: true });
            } catch { element.textContent = source; }
        }
    }
    for (const element of fragment.querySelectorAll('[id]')) element.id = 'msg-' + element.id;
    for (const link of fragment.querySelectorAll('a[href]')) {
        const href = link.getAttribute('href');
        if (href.startsWith('#')) link.setAttribute('href', '#msg-' + href.slice(1));
        else if (!/^(https?:\/\/|mailto:)/i.test(href)) link.removeAttribute('href');
    }
    return fragment;
}

// Format whitespace only. Keep large integers, duplicate keys and the sender's escape sequences intact.
function readableJSON(source) {
    try { JSON.parse(source); } catch { return source; }
    const pieces = [];
    let depth = 0, end = 0, previous = '';
    const newline = () => '\n' + '  '.repeat(Math.min(64, depth));
    const tokens = source.matchAll(/"(?:\\[\s\S]|[^"\\])*"|[^\s,:\[\]{}]+|[,\[\]{}:]/gu);
    for (const token of tokens) {
        const value = token[0];
        if (value === '}' || value === ']') {
            depth--;
            if (previous !== '[' && previous !== '{') pieces.push(newline());
        } else if (previous === '{' || previous === '[' || previous === ',') pieces.push(newline());
        pieces.push(value === ':' ? ': ' : value);
        if (value === '{' || value === '[') depth++;
        previous = value;
        end = token.index + value.length;
    }
    return end ? pieces.join('') : source;
}

function sourceBlock(text, language) {
    const pre = document.createElement('pre');
    const code = document.createElement('code');
    if (language) code.className = 'language-' + language;
    code.textContent = text;
    pre.append(code);
    return pre;
}

function actionButton(label, onClick) {
    const button = document.createElement('button');
    button.type = 'button';
    button.textContent = label;
    button.addEventListener('click', onClick);
    return button;
}

function styleCode(pre, copySource) {
    const code = pre.querySelector(':scope > code') || pre;
    const language = [...code.classList].find(name => name.startsWith('language-'))?.slice(9);
    const source = code.textContent;
    const block = document.createElement('div');
    block.className = 'code-block';
    const bar = document.createElement('div');
    bar.className = 'code-bar';
    const label = document.createElement('span');
    label.textContent = language?.toLowerCase() === 'json' ? 'JSON' : language || labelFor('Code');
    const wrap = actionButton(labelFor('Wrap lines'), () => {
        wrap.setAttribute('aria-pressed', String(pre.classList.toggle('wrap')));
    });
    wrap.setAttribute('aria-pressed', 'false');
    const copy = actionButton(labelFor('Copy'), () => {
        window.webkit?.messageHandlers.copyCode.postMessage(copySource ?? source);
        copy.textContent = labelFor('Copied');
        setTimeout(() => { copy.textContent = labelFor('Copy'); }, 1300);
    });
    bar.append(label, wrap, copy);
    pre.replaceWith(block);
    block.append(bar, pre);
    if (language && source.length <= 80000 && hljs.getLanguage(language)) {
        code.innerHTML = hljs.highlight(source, { language, ignoreIllegals: true }).value;
    }
    pre.tabIndex = 0;
}

function styleTask(element) {
    const start = element.firstChild;
    if (start?.nodeType !== Node.TEXT_NODE) return;
    const match = start.nodeValue.match(/^(?:[.•] )?\[([ xX])\](?:[ \t]+|$)/);
    if (!match) return;
    start.deleteData(0, match[0].length);
    const done = match[1].toLowerCase() === 'x';
    const box = document.createElement('span');
    box.className = 'task-state' + (done ? ' done' : '');
    box.setAttribute('role', 'img');
    box.setAttribute('aria-label', done ? labelFor('Completed') : labelFor('Not completed'));
    element.prepend(box);
    const item = element.closest('li');
    if (item) item.classList.add('task');
    else element.classList.add('task-paragraph');
}

function styleImage(image) {
    const alt = image.alt.trim();
    const fallback = () => {
        const label = document.createElement('span');
        label.className = 'image-fallback';
        label.textContent = alt || labelFor('Image unavailable');
        image.replaceWith(label);
    };
    if (!image.hasAttribute('src')) { fallback(); return; }
    image.addEventListener('error', fallback, { once: true });
    const parent = image.parentElement;
    if (parent?.tagName !== 'P' || parent.childNodes.length !== 1 || parent.closest('figure')) return;
    const figure = document.createElement('figure');
    parent.replaceWith(figure);
    figure.append(image);
    const legend = image.getAttribute('title') || alt;
    if (legend) {
        const caption = document.createElement('figcaption');
        caption.textContent = legend;
        figure.append(caption);
        image.addEventListener('error', () => { if (legend === alt) caption.remove(); }, { once: true });
    }
}

const message = document.querySelector('#message');
const envelope = document.querySelector('#envelope');
let readerLabels = {};
function labelFor(key) { return readerLabels[key] ?? key; }

function renderMessage(data) {
    readerLabels = data.labels ?? {};
    document.documentElement.lang = (data.language || 'en').replaceAll('_', '-');
    document.title = data.title;
    document.querySelector('main').classList.toggle('floating', !data.envelope);
    envelope.hidden = !data.envelope;
    document.querySelector('#subject').textContent = data.title;
    document.querySelector('#author').textContent = data.sender;
    document.querySelector('#folder').textContent = data.folder;
    document.querySelector('#sent').textContent = data.date;
    const icon = document.querySelector('#sender-mark');
    icon.hidden = !data.icon;
    if (data.icon) icon.src = data.icon;

    try {
        const content = document.createDocumentFragment();
        if (data.format === 'text') {
            const plain = document.createElement('p');
            plain.className = 'plain-text';
            plain.textContent = data.text;
            content.append(plain);
        } else if (data.format === 'code' || data.format === 'json') {
            const json = data.format === 'json';
            content.append(sourceBlock(json ? readableJSON(data.text) : data.text, json ? 'json' : null));
        } else {
            content.append(richContent(data.text));
            const first = content.firstElementChild;
            if (data.envelope && first?.matches('h1,h2,h3,h4,h5,h6,p') &&
                !first.querySelector('img,br') && first.textContent.trim() === data.title.trim()) first.remove();
            for (const node of content.querySelectorAll('li, p')) styleTask(node);
            for (const table of content.querySelectorAll('table')) {
                const overflow = document.createElement('div');
                overflow.className = 'table-scroll';
                overflow.tabIndex = 0;
                overflow.setAttribute('role', 'region');
                overflow.setAttribute('aria-label', table.caption?.textContent || labelFor('Table'));
                table.replaceWith(overflow);
                overflow.append(table);
            }
            for (const img of content.querySelectorAll('img')) styleImage(img);
        }
        for (const pre of content.querySelectorAll('pre')) styleCode(pre, data.format === 'json' ? data.text : null);
        message.replaceChildren(content);
    } catch {
        const plain = document.createElement('p');
        plain.className = 'plain-text';
        plain.textContent = data.text;
        message.replaceChildren(plain);
    }
    const thread = document.querySelector('#replies');
    const last = thread.lastElementChild?.dataset.reply;
    const sameMessage = thread.dataset.message === data.id;
    thread.dataset.message = data.id;
    thread.replaceChildren();
    for (const reply of data.replies ?? []) {
        const turn = document.createElement('section');
        turn.dataset.reply = reply.id;
        const author = document.createElement('strong');
        author.textContent = data.you;
        const question = document.createElement('p');
        question.className = 'plain-text';
        question.textContent = reply.question;
        const sender = document.createElement('strong');
        sender.textContent = reply.delivery === 'queued' || reply.delivery === 'failed' ? 'Vellem' : data.sender;
        const answer = document.createElement('article');
        if (reply.delivery === 'queued') {
            answer.className = 'reply-pending';
            answer.textContent = reply.answer;
        } else {
            answer.append(richContent(reply.answer));
            for (const pre of answer.querySelectorAll('pre')) styleCode(pre);
            for (const img of answer.querySelectorAll('img')) styleImage(img);
        }
        turn.append(author, question, sender, answer);
        thread.append(turn);
    }
    if (!sameMessage) window.scrollTo(0, 0);
    else if (thread.lastElementChild && last !== thread.lastElementChild.dataset.reply) {
        thread.lastElementChild.scrollIntoView({block: 'start'});
    }
}

function readerAppearance(size, dark) {
    document.documentElement.style.setProperty('--size', size + 'px');
    document.documentElement.classList.toggle('dark', dark);
}
