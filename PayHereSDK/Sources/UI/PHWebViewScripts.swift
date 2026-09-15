// Internal JavaScript used by the payment web view.
internal enum PHWebViewScripts {
    static let viewport = """
    var meta = document.createElement('meta');
    meta.name = 'viewport';
    meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, minimum-scale=1.0, user-scalable=no';
    document.getElementsByTagName('head')[0].appendChild(meta);
    """

    // Match the hosted form's DOM, not its payment provider's URL. Unknown pages are untouched.
    static let cardFormLayout = """
    (() => {
        const forms = document.querySelectorAll('body > .container > form#paymentForm');
        if (forms.length !== 1) return;
        const form = forms[0];
        const isVisible = element => {
            const bounds = element.getBoundingClientRect();
            return bounds.width > 0 && bounds.height > 0 &&
                getComputedStyle(element).visibility === 'visible';
        };
        const fieldSets = [
            ['cardHolderName', 'cardNo', 'cardSecureId', 'cardExpiry'],
            ['cardholder-name', 'card-number', 'cardSecureId', 'expiry-month', 'expiry-year']
        ];
        const hasCardFields = fieldSets.some(fields => fields.every(id => {
            const field = form.querySelector('#' + id);
            return field && field.matches('input, select') && field.type !== 'hidden' &&
                field.form === form && isVisible(field);
        }));
        const payButton = form.querySelector('button#payButton.btn-primary, button[type="submit"].btn-primary');
        if (!hasCardFields || !payButton || payButton.type !== 'submit' ||
            payButton.form !== form || !isVisible(payButton)) {
            return;
        }

        // The hosted card form has a fixed height that leaves empty scrollable space.
        form.parentElement.style.setProperty('height', 'auto', 'important');
        form.parentElement.setAttribute('data-payhere-sdk-card-form', '');
        payButton.setAttribute('data-payhere-sdk-card-submit', '');

        // Let the empty footer size naturally without changing the submit button's baseline.
        const footer = payButton.parentElement;
        if (footer.parentElement === form && footer === form.lastElementChild &&
            footer.matches('.form-group') && footer.children.length === 1 &&
            footer.textContent.trim() === payButton.textContent.trim()) {
            const buttonBounds = payButton.getBoundingClientRect();
            if (buttonBounds.bottom <= footer.getBoundingClientRect().top) {
                footer.style.setProperty('height', 'auto', 'important');
                footer.style.setProperty('margin-bottom', '0', 'important');
            }
        }
    })();
    """

    static let cardFormMeasurement = """
    (() => {
        window.scrollTo(0, 0);
        const container = document.querySelector('body > .container[data-payhere-sdk-card-form]');
        if (!container) return null;

        const bounds = container.getBoundingClientRect();
        const payButton = container.querySelector('button[data-payhere-sdk-card-submit]');
        const buttonBounds = payButton && payButton.getBoundingClientRect();
        // A fixed-height footer can be shorter than its visible submit button.
        const contentBottom = Math.max(bounds.bottom, bounds.top + container.scrollHeight,
                                       buttonBounds ? buttonBounds.bottom : bounds.bottom);
        return {
            height: Math.ceil(contentBottom + window.scrollY),
            bottomSpacing: buttonBounds && buttonBounds.height > 0
                ? Math.max(0, contentBottom - buttonBounds.bottom) : 0
        };
    })();
    """
}
