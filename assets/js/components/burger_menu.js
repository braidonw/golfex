/* Inspired by https://piccalil.li/blog/build-a-fully-responsive-progressively-enhanced-burger-menu */
import getFocusableElements from "../get-focusable-elements.js";

class BurgerMenu extends HTMLElement {
  constructor() {
    // initialize the HTML element
    super();

    const self = this;

    this.state = new Proxy(
      {
        status: "open",
        enabled: false,
      },
      {
        set(state, key, value) {
          const oldValue = state[key];

          state[key] = value;
          if (oldValue !== value) {
            self.processStateChange();
          }
          return state;
        },
      },
    );
  }

  get maxWidth() {
    return parseInt(this.getAttribute("max-width") || 9999, 10);
  }

  connectedCallback() {
    this.initialMarkup = this.innerHTML;
    this.render();

    /* The ResizeObserver gives us a callback, every time the observed element changes size—in our case, the <burger-menu> parent, which happens to be .site-head__inner—we can monitor it and if needed, react to it. */
    const observer = new ResizeObserver((observedItems) => {
      const { contentRect } = observedItems[0];
      this.state.enabled = contentRect.width <= this.maxWidth;
    });

    // We want to watch the parent like a hawk
    observer.observe(this.parentNode);
  }

  render() {
    this.innerHTML = `
      <div class="burger-menu" data-element="burger-root">
        <button class="burger-menu__trigger" data-element="burger-menu-trigger" type="button" aria-label="Open menu">
          <span class="burger-menu__bar" aria-hidden="true"></span>
        </button>
        <div class="burger-menu__panel" data-element="burger-menu-panel">
          ${this.initialMarkup}
        </div>
      </div>
    `;

    this.postRender();
  }

  // Runs after the 'render' function

  /* The first thing we do is grab the elements we want. I personally like to use [data-element] attributes for selecting elements with JavaScript, but really, do whatever works for you and your team. I certainly don’t do it for any good reason other than it makes it more obvious what elements have JavaScript attached to them.

  The next thing we do is test to see if the trigger and panel are both present. Without both of these, our burger menu is redundant. If they are both there, we fire off the yet-to-be-defined toggle() method and wire up a click event to our trigger element, which again, fires off the toggle() method. */
  postRender() {
    this.trigger = this.querySelector('[data-element="burger-menu-trigger"]');
    this.panel = this.querySelector('[data-element="burger-menu-panel"]');
    this.root = this.querySelector('[data-element="burger-root"]');
    this.focusableElements = getFocusableElements(this);

    if (this.trigger && this.panel) {
      this.toggle();

      this.trigger.addEventListener("click", (evt) => {
        evt.preventDefault();

        this.toggle();
      });

      document.addEventListener("focusin", () => {
        if (!this.contains(document.activeElement)) {
          this.toggle("closed");
        }
      });

      return;
    }

    this.innerHTML = this.initialMarkup;
  }

  /* In toggle(), we can pass an optional forcedStatus parameter which—just like in the above focus management—let’s us force the component into a specific, finite state: 'open' or 'closed'. If that isn’t defined, we set the current state.status to be open or closed, depending on what the current status is, using a ternary operator. */
  toggle(forcedStatus) {
    if (forcedStatus) {
      if (this.state.status === forcedStatus) {
        return;
      }

      this.state.status = forcedStatus;
    } else {
      this.state.status = this.state.status === "closed" ? "open" : "closed";
    }
  }

  /* This method is fired every time state changes, so its only job is to grab the current state of our component and reflect it where necessary. The first part of that is setting our root element’s attributes. We’re going to use this as style hooks later. Then, we set the aria-expanded attribute and the aria-label attribute on our trigger. We’ll do the actual visual toggling of the panel with CSS. */
  processStateChange() {
    this.root.setAttribute("status", this.state.status);
    this.root.setAttribute("enabled", this.state.enabled ? "true" : "false");

    this.manageFocus();

    switch (this.state.status) {
      case "closed":
        this.trigger.setAttribute("aria-expanded", "false");
        this.trigger.setAttribute("aria-label", "Open menu");
        break;
      case "open":
      case "initial":
        this.trigger.setAttribute("aria-expanded", "true");
        this.trigger.setAttribute("aria-label", "Close menu");
        break;
    }
  }

  /* Here, we look grab our focusable elements (we’re doing that bit next) and then depending on wether or not we’re in an open or closed, state, we add tabindex="-1" or remove it. We add it when we in a closed state because if you remember rightly, this prevents keyboard focus. For the same reason we automatically closed the menu when focus escaped in the open state, earlier, we are now preventing focus from leaking in if it is closed. */
  manageFocus() {
    if (!this.state.enabled) {
      this.focusableElements.forEach((element) =>
        element.removeAttribute("tabindex"),
      );
      return;
    }

    switch (this.state.status) {
      case "open":
        this.focusableElements.forEach((element) =>
          element.removeAttribute("tabindex"),
        );
        break;
      case "closed":
        [...this.focusableElements]
          .filter(
            (element) =>
              element.getAttribute("data-element") !== "burger-menu-trigger",
          )
          .forEach((element) => element.setAttribute("tabindex", "-1"));
        break;
    }
  }
}

export default BurgerMenu;
