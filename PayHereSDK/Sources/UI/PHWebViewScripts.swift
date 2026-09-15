// Internal JavaScript used by the payment web view.
internal enum PHWebViewScripts {
    static let viewport = """
    var meta = document.createElement('meta');
    meta.name = 'viewport';
    meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, minimum-scale=1.0, user-scalable=no';
    document.getElementsByTagName('head')[0].appendChild(meta);
    """

    // Match the hosted form's DOM, not its payment provider's URL. Unknown pages are untouched.
    static let cardFormLayout = cardFormScript("""
        const forms = document.querySelectorAll(selectors.form);
        if (forms.length !== 1) return;
        const form = forms[0];
        const isVisible = element => {
            const bounds = element.getBoundingClientRect();
            return bounds.width > 0 && bounds.height > 0 &&
                getComputedStyle(element).visibility === 'visible';
        };
        const hasCardFields = selectors.fieldSets.some(fields => fields.every(selector => {
            const field = form.querySelector(selector);
            return field && field.matches('input, select') && field.type !== 'hidden' &&
                field.form === form && isVisible(field);
        }));
        const submitControl = form.querySelector(selectors.submit);
        if (!hasCardFields || !submitControl || submitControl.type !== 'submit' ||
            submitControl.form !== form || !isVisible(submitControl)) {
            return;
        }

        // The hosted card form has a fixed height that leaves empty scrollable space.
        const container = form.parentElement;
        container.style.setProperty('height', 'auto', 'important');
        container.setAttribute(selectors.formMarker, '');

        // Fixed side margins plus the provider's percentage minimum width can
        // exceed a narrow sheet. Bound the button's entire horizontal box,
        // retaining its original sizing, vertical metrics, and responsive minimum.
        if (!submitControl.hasAttribute(selectors.submitMarker)) {
            const style = getComputedStyle(submitControl);
            const pixels = value => parseFloat(value) || 0;
            const edges = pixels(style.marginLeft) + pixels(style.marginRight) +
                (style.boxSizing === 'border-box' ? 0 :
                    pixels(style.paddingLeft) + pixels(style.paddingRight) +
                    pixels(style.borderLeftWidth) + pixels(style.borderRightWidth));
            const availableWidth = 'max(0px, calc(100% - ' + edges + 'px))';
            const minimumWidth = style.minWidth;
            const maximumWidth = style.maxWidth;
            submitControl.style.setProperty('min-width', 'min(' + minimumWidth + ', ' + availableWidth + ')', 'important');
            submitControl.style.setProperty('max-width', maximumWidth === 'none' ? availableWidth :
                'min(' + maximumWidth + ', ' + availableWidth + ')', 'important');
        }
        submitControl.setAttribute(selectors.submitMarker, '');

        // The provider's adjacent logo/disclosure container shares the same fixed height.
        // Resize only that recognized footer, retaining its contents and any legal links.
        const pageFooter = container.nextElementSibling;
        if (pageFooter && pageFooter.matches(selectors.container) &&
            pageFooter.querySelector(selectors.footerLogo) &&
            pageFooter.querySelector(selectors.footerDeclaration) &&
            !pageFooter.querySelector('form, input, select, textarea, button, iframe')) {
            pageFooter.style.setProperty('height', 'auto', 'important');
            pageFooter.setAttribute(selectors.footerMarker, '');
        }

        // Let the empty footer size naturally without changing the submit button's baseline.
        const footer = submitControl.parentElement;
        if (footer.parentElement === form && footer === form.lastElementChild &&
            footer.matches('.form-group') && footer.children.length === 1 &&
            footer.textContent.trim() === submitControl.textContent.trim()) {
            const buttonBounds = submitControl.getBoundingClientRect();
            if (buttonBounds.bottom <= footer.getBoundingClientRect().top) {
                footer.style.setProperty('height', 'auto', 'important');
                footer.style.setProperty('margin-bottom', '0', 'important');
            }
        }
    """)

    static let cardFormMeasurement = cardFormScript("""
        const container = document.querySelector('body > ' + selectors.container + '[' + selectors.formMarker + ']');
        if (!container) return null;

        const bounds = container.getBoundingClientRect();
        const submitControl = container.querySelector('button[' + selectors.submitMarker + ']');
        const buttonBounds = submitControl && submitControl.getBoundingClientRect();
        if (!buttonBounds || buttonBounds.height <= 0) return null;

        // Measure painted content, not wrapper padding or the viewport's minimum height.
        let contentBottom = buttonBounds.bottom;
        const isVisible = element => {
            const style = getComputedStyle(element);
            return style.display !== 'none' && style.visibility === 'visible' && style.opacity !== '0';
        };
        const textNodes = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
        const range = document.createRange();
        let node;
        while ((node = textNodes.nextNode())) {
            const parent = node.parentElement;
            if (!parent || !node.textContent.trim() || !isVisible(parent) ||
                getComputedStyle(parent).fontSize === '0px') continue;
            range.selectNodeContents(node);
            const textBounds = range.getBoundingClientRect();
            if (textBounds.width > 0 && textBounds.height > 0) {
                contentBottom = Math.max(contentBottom, textBounds.bottom);
            }
        }
        // Preserve actual logos, controls, and disclosures; empty image placeholders add no content.
        for (const element of document.body.querySelectorAll('img, svg, canvas, video, iframe, input, select, textarea, button')) {
            if (!isVisible(element)) continue;
            if (element.tagName === 'IMG' && !element.naturalWidth && !element.alt.trim() &&
                !element.getAttribute('src') && !element.getAttribute('srcset')) continue;
            const elementBounds = element.getBoundingClientRect();
            if (elementBounds.width > 0 && elementBounds.height > 0) {
                contentBottom = Math.max(contentBottom, elementBounds.bottom);
            }
        }

        // The root's layout box includes collapsed body/child margins. Its scrollHeight
        // also includes unused viewport height, which must not become form content.
        let rootBottom = Math.max(document.documentElement.getBoundingClientRect().bottom,
                                  document.body.getBoundingClientRect().bottom,
                                  bounds.bottom, bounds.top + container.scrollHeight, contentBottom);
        const pageFooter = container.nextElementSibling;
        if (pageFooter && pageFooter.hasAttribute(selectors.footerMarker)) {
            const footerBounds = pageFooter.getBoundingClientRect();
            rootBottom = Math.max(rootBottom, footerBounds.bottom,
                                  footerBounds.top + pageFooter.scrollHeight);
        }
        const height = Math.ceil(contentBottom + window.scrollY);
        return {
            height,
            bottomSpacing: Math.max(0, Math.ceil(rootBottom + window.scrollY) - height)
        };
    """)

    static let pageMeasurement = """
    (() => {
        let card = \(cardFormMeasurement)
        if (!card) {
            // Controls can arrive after document-end. Once recognized, avoid
            // repeating style writes that would notify our own layout observer.
            \(cardFormLayout)
            card = \(cardFormMeasurement)
        }
        const result = {
            kind: card ? 'card' : 'page',
            height: card ? card.height : 0,
            bottomSpacing: card ? card.bottomSpacing : 0,
            viewportWidth: window.innerWidth,
            viewportHeight: window.innerHeight,
            viewportFloorBottom: 0,
            documentHeight: (document.scrollingElement || document.documentElement).scrollHeight,
            documentID: window.__payhereLayoutDocumentID
        };
        if (card || !document.body) return result;

        // Root and wrapper heights may be viewport floors, not intrinsic content.
        // Measure visible text and replaced elements without rewriting bank pages.
        const rendering = new WeakMap();
        const isRendered = element => {
            if (!element) return true;
            if (rendering.has(element)) return rendering.get(element);
            const style = getComputedStyle(element);
            // Fixed content belongs to the viewport, not the document's height.
            const visible = style.display !== 'none' && style.position !== 'fixed' &&
                Number(style.opacity) !== 0 && !element.matches('script, style, noscript, template') &&
                isRendered(element.parentElement);
            rendering.set(element, visible);
            return visible;
        };
        // Unlike display and opacity, inherited visibility can be overridden by a child.
        const isVisible = element => element &&
            getComputedStyle(element).visibility === 'visible' && isRendered(element);
        const viewportFlexLayouts = new WeakMap();
        const followsViewportFloor = element => {
            for (let child = element, parent = element.parentElement; parent;
                 child = parent, parent = parent.parentElement) {
                const childStyle = getComputedStyle(child);
                if (childStyle.position === 'absolute' || childStyle.position === 'fixed') return false;
                if (!viewportFlexLayouts.has(parent)) {
                    const style = getComputedStyle(parent);
                    const bounds = parent.getBoundingClientRect();
                    const isColumn = (style.display === 'flex' || style.display === 'inline-flex') &&
                        (style.flexDirection === 'column' || style.flexDirection === 'column-reverse');
                    const fillsViewport = Math.abs(bounds.height - window.innerHeight) <= 1 ||
                        Math.abs(bounds.bottom + window.scrollY - window.innerHeight) <= 1;
                    let distributesSpace = false;
                    if (isColumn && fillsViewport) {
                        const pixels = value => parseFloat(value) || 0;
                        const items = Array.from(parent.children).map(element => ({
                            element, style: getComputedStyle(element), bounds: element.getBoundingClientRect()
                        })).filter(item => item.style.display !== 'none' &&
                            item.style.position !== 'absolute' && item.style.position !== 'fixed');
                        const innerHeight = parent.clientHeight - pixels(style.paddingTop) - pixels(style.paddingBottom);
                        const occupiedHeight = items.reduce((total, item) => total + item.bounds.height +
                            pixels(item.style.marginTop) + pixels(item.style.marginBottom), 0) +
                            pixels(style.rowGap) * Math.max(0, items.length - 1);
                        const distributedGap = innerHeight - occupiedHeight > 1 &&
                            ['space-between', 'space-around', 'space-evenly', 'flex-end', 'end'].includes(style.justifyContent);
                        const expandedFiller = items.some(item => pixels(item.style.flexGrow) > 0 &&
                            item.element.children.length === 0 && !item.element.textContent.trim() &&
                            !item.element.matches('img, svg, canvas, video, iframe, input, select, textarea, button, object, embed, hr') &&
                            item.bounds.height - pixels(item.style.paddingTop) - pixels(item.style.paddingBottom) -
                                pixels(item.style.borderTopWidth) - pixels(item.style.borderBottomWidth) > 1);
                        distributesSpace = distributedGap || expandedFiller;
                    }
                    viewportFlexLayouts.set(parent, isColumn && fillsViewport && distributesSpace
                        ? bounds.bottom + window.scrollY - (parseFloat(style.paddingBottom) || 0) -
                            (parseFloat(style.borderBottomWidth) || 0)
                        : null);
                }
                const floor = viewportFlexLayouts.get(parent);
                if (floor !== null && Math.abs(child.getBoundingClientRect().bottom + window.scrollY +
                    (parseFloat(childStyle.marginBottom) || 0) - floor) <= 1) return true;
            }
            return false;
        };
        let contentBottom = 0;
        const include = (bounds, element) => {
            if (bounds.width > 0 && bounds.height > 0) {
                contentBottom = Math.max(contentBottom, bounds.bottom + window.scrollY);
                if (followsViewportFloor(element)) {
                    result.viewportFloorBottom = Math.max(result.viewportFloorBottom,
                        Math.max(0, Math.ceil(bounds.bottom + window.scrollY)));
                }
            }
        };
        const textNodes = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
        const range = document.createRange();
        let node;
        while ((node = textNodes.nextNode())) {
            if (!node.textContent.trim() || !isVisible(node.parentElement) ||
                getComputedStyle(node.parentElement).fontSize === '0px') continue;
            range.selectNodeContents(node);
            include(range.getBoundingClientRect(), node.parentElement);
        }
        for (const element of document.body.querySelectorAll('img, svg, canvas, video, iframe, input, select, textarea, button')) {
            if (!isVisible(element)) continue;
            if (element.tagName === 'IMG' && !element.naturalWidth && !element.alt.trim() &&
                !element.getAttribute('src') && !element.getAttribute('srcset')) continue;
            const bounds = element.getBoundingClientRect();
            if (element.tagName === 'IFRAME' && bounds.width > 0 && bounds.height > 0 &&
                (Math.abs(parseFloat(getComputedStyle(element).height) - window.innerHeight) <= 1 ||
                 Math.abs(bounds.height - window.innerHeight) <= 1 ||
                 Math.abs(bounds.bottom + window.scrollY - window.innerHeight) <= 1)) {
                // Matching the viewport is only a feedback hint: a fixed-height
                // frame also matches after fitting. Never discard its outer demand.
                result.viewportFloorBottom = Math.max(result.viewportFloorBottom,
                    Math.max(0, Math.ceil(bounds.bottom + window.scrollY)));
            }
            include(bounds, element);
        }
        result.height = Math.max(0, Math.ceil(contentBottom));
        return result;
    })();
    """

    static let layoutObserver = """
    (() => {
        if (window.__payhereLayoutObserverInstalled) return;
        window.__payhereLayoutObserverInstalled = true;
        const documentID = Array.from(crypto.getRandomValues(new Uint32Array(4)),
                                      value => value.toString(16)).join('-');
        window.__payhereLayoutDocumentID = documentID;
        let pending = false;
        const notify = () => {
            if (pending) return;
            pending = true;
            setTimeout(() => {
                pending = false;
                const handler = window.webkit && window.webkit.messageHandlers &&
                    window.webkit.messageHandlers.payhereLayoutChanged;
                if (handler) handler.postMessage(documentID);
            }, 100);
        };
        const mutations = new MutationObserver(notify);
        mutations.observe(document.documentElement, {
            childList: true, subtree: true, attributes: true, characterData: true
        });
        if (typeof ResizeObserver === 'function') {
            const sizes = new ResizeObserver(notify);
            sizes.observe(document.documentElement);
            if (document.body) sizes.observe(document.body);
        }
        window.addEventListener('resize', notify);
        window.addEventListener('load', notify, true);
        if (document.fonts) {
            document.fonts.ready.then(notify);
            document.fonts.addEventListener('loadingdone', notify);
        }
        notify();
    })();
    """

    private static func cardFormScript(_ body: String) -> String {
        return #"""
        (() => {
            const selectors = {
                form: '\x62\x6f\x64\x79\x20\x3e\x20\x2e\x63\x6f\x6e\x74\x61\x69\x6e\x65\x72\x20\x3e\x20\x66\x6f\x72\x6d\x23\x70\x61\x79\x6d\x65\x6e\x74\x46\x6f\x72\x6d',
                fieldSets: [
                    [
                        '\x23\x63\x61\x72\x64\x48\x6f\x6c\x64\x65\x72\x4e\x61\x6d\x65',
                        '\x23\x63\x61\x72\x64\x4e\x6f',
                        '\x23\x63\x61\x72\x64\x53\x65\x63\x75\x72\x65\x49\x64',
                        '\x23\x63\x61\x72\x64\x45\x78\x70\x69\x72\x79'
                    ],
                    [
                        '\x23\x63\x61\x72\x64\x68\x6f\x6c\x64\x65\x72\x2d\x6e\x61\x6d\x65',
                        '\x23\x63\x61\x72\x64\x2d\x6e\x75\x6d\x62\x65\x72',
                        '\x23\x63\x61\x72\x64\x53\x65\x63\x75\x72\x65\x49\x64',
                        '\x23\x65\x78\x70\x69\x72\x79\x2d\x6d\x6f\x6e\x74\x68',
                        '\x23\x65\x78\x70\x69\x72\x79\x2d\x79\x65\x61\x72'
                    ]
                ],
                submit: '\x62\x75\x74\x74\x6f\x6e\x23\x70\x61\x79\x42\x75\x74\x74\x6f\x6e\x2e\x62\x74\x6e\x2d\x70\x72\x69\x6d\x61\x72\x79\x2c\x20\x62\x75\x74\x74\x6f\x6e\x5b\x74\x79\x70\x65\x3d\x22\x73\x75\x62\x6d\x69\x74\x22\x5d\x2e\x62\x74\x6e\x2d\x70\x72\x69\x6d\x61\x72\x79',
                container: '\x2e\x63\x6f\x6e\x74\x61\x69\x6e\x65\x72',
                footerLogo: '\x2e\x72\x6f\x77\x2e\x74\x65\x78\x74\x2d\x63\x65\x6e\x74\x65\x72\x20\x3e\x20\x69\x6d\x67\x2e\x73\x63\x68\x65\x6d\x65\x2d\x6c\x6f\x67\x6f',
                footerDeclaration: '\x70\x2e\x64\x65\x63\x6c\x61\x72\x61\x74\x69\x6f\x6e\x2d\x74\x65\x78\x74',
                formMarker: '\x64\x61\x74\x61\x2d\x70\x61\x79\x68\x65\x72\x65\x2d\x73\x64\x6b\x2d\x63\x61\x72\x64\x2d\x66\x6f\x72\x6d',
                submitMarker: '\x64\x61\x74\x61\x2d\x70\x61\x79\x68\x65\x72\x65\x2d\x73\x64\x6b\x2d\x63\x61\x72\x64\x2d\x73\x75\x62\x6d\x69\x74',
                footerMarker: '\x64\x61\x74\x61\x2d\x70\x61\x79\x68\x65\x72\x65\x2d\x73\x64\x6b\x2d\x63\x61\x72\x64\x2d\x66\x6f\x6f\x74\x65\x72'
            };
        \#(body)
        })();
        """#
    }
}
