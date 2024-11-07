import { Controller } from "stimulus"
import Sortable from "sortablejs"

var bs4 = document.documentElement.dataset.bs4 == "true";

// Manages the sorting and commonality threshold clamping for the SEP types list.
export default class extends Controller {

  static targets = ["marketTab", "thresholdInput", "commonQleList", "thresholdMarker", "rareQleList"]

  get marketKind() {
    return this.marketTabTarget.id;
  }

  /**
  * Create the managers used to handle update list requests.
  */
  initialize() {
    this.orderManager = new UpdateOrderManager(this.marketKind, this.commonQleListTarget, this.thresholdMarkerTarget, this.rareQleListTarget);
    if (this.hasThresholdInputTarget) {
      this.thresholdManager = new UpdateThresholdManager(this.marketKind, this.commonQleListTarget, this.thresholdMarkerTarget, this.rareQleListTarget, this.thresholdInputTarget);
    }
  }

  /**
  * Configure the order manager to handle sorting the QLE list.
  */
	connect() {
    this.orderManager.configureSortable();
	}

  /**
  * Update the threshold in the threshold manager.
  */
  setThreshold() {
    this.thresholdManager.set();
  }
}

// Base manager used to handle update list requests and response banners.
class UpdateListManager {

  constructor(marketKind, commonQleListTarget, thresholdMarkerTarget, rareQleListTarget) {
    this.marketKind = marketKind;
    this.commonQleListTarget = commonQleListTarget;
    this.thresholdMarkerTarget = thresholdMarkerTarget;
    this.rareQleListTarget = rareQleListTarget;
  }

  /**
   * Perform a PATCH request to update the QLE list and shows the response banner.
   * @param {Object} body The request body containing the list update data.
   * @param {String} bannerDescription The message to use in the legacy response banner subheader.
   * @returns {Bool} The success status of the request.
   */
  async updateList(body, bannerDescription) {
    body.market_kind = this.marketKind;
		const response = await fetch('update_list', {
      method: 'PATCH',
      body: JSON.stringify(body),
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector("meta[name=csrf-token]").content
      }
    });

    let data = await response.json();
    let isSuccess = data["status"] === "success";
    this.showBanner(isSuccess, data["message"], bannerDescription);

    return isSuccess;
  }

  /**
   * Show or hide the respective response banner.
   * @param {boolean} isSuccess The success status of the request.
   * @param {string} bannerTitle The message to use in the legacy response banner header.
   * @param {string} bannerDescription The message to use in the legacy response banner subheader.
   */
  showBanner(isSuccess, bannerTitle, bannerDescription) {
    if (bs4) {
      const successBanner = $('#success-flash');
      const errorBanner = $('#error-flash');
      successBanner.toggleClass('hidden', !isSuccess)
      errorBanner.toggleClass('hidden', isSuccess)
      var flashDiv = isSuccess ? successBanner : errorBanner;
    } else {
      var flashDiv = $("#sort_notification_msg");
      var flashHeader = flashDiv.find(".toast-header");
      flashDiv.show();

      flashDiv.removeClass("success").removeClass("error");
      flashDiv.toggleClass("success", isSuccess).toggleClass("error", !isSuccess);
      flashHeader.removeClass("success").removeClass("error");
      flashHeader.toggleClass("success", isSuccess).toggleClass("error", !isSuccess);

      flashHeader.find("strong").text(bannerTitle);

      var flashBody = flashDiv.find(".toast-body");
      if (bannerDescription) {
        flashBody.removeClass("hidden").text(bannerDescription);
      } else {
        flashBody.addClass("hidden");
      }
    }

    setTimeout(function() {
      flashDiv.addClass('hidden');
    }, 3500);
  }
}

// Manages the sorting of the SEP types list.
class UpdateOrderManager extends UpdateListManager {

  static #QLE_SORTABLE_GROUP = 'qle-sortable';

  /**
  * Initialize the Sortable library using the `CrossListSortable` instance wrapping the two QLE lists.
  */
  configureSortable() {
		this.qleListSortable = new CrossListSortable(this.commonQleListTarget, this.rareQleListTarget, {
      group: UpdateOrderManager.#QLE_SORTABLE_GROUP,
      onEnd: this.#updateOrder.bind(this)
    });
  }

  /**
  * Handle updating the sort order for a QLE list.
  * Performs the PATCH request and shows the response banner.
  */
	#updateOrder(event) {
    if (event.from === event.to && event.oldIndex === event.newIndex) { return }

    // Call `toArray` on the sortable to get the new order of the QLEs by `data-id`, then map the ids to their new positions.
    let sortData = this.qleListSortable.toArray().map((id, index) => { return { id: id, position: index + 1 } });
    super.updateList({sort_data: sortData}, event.item.textContent);
	}
}


// Manages the commonality threshold input and marker for the SEP types list.
class UpdateThresholdManager extends UpdateListManager {

  constructor(marketKind, commonQleListTarget, thresholdMarkerTarget, rareQleListTarget, thresholdInputTarget) {
    super(marketKind, commonQleListTarget, thresholdMarkerTarget, rareQleListTarget);
    this.thresholdInputTarget = thresholdInputTarget;
  }

  /**
  * Handle updating the commonality threshold for a QLE list.
  * Performs the PATCH request, then updates the threshold marker element and shows the banner based on the response.
  */
  set() {
    let threshold = this.thresholdInputTarget.value;

    super.updateList({commonality_threshold: threshold})
      .then(isSuccess => {
        if (isSuccess) {
          this.thresholdInputTarget.dataset.initialValue = threshold;
          this.#shiftElements(threshold);
        } else {
          this.thresholdInputTarget.value = this.thresholdInputTarget.dataset.initialValue;
        }
      });
  }

  /**
   * Shift the elements between the common and rare QLE lists based on the threshold value, and hides/shows it depending on the existence of rare children.
   * @param {Number} threshold The threshold value to determine the number of common QLEs.
   */
  #shiftElements(threshold) {
    while (this.commonQleListTarget.children.length < threshold && this.rareQleListTarget.children.length > 0) {
      this.commonQleListTarget.appendChild(this.rareQleListTarget.firstElementChild);
    }
    while (this.commonQleListTarget.children.length > threshold) {
      this.rareQleListTarget.prepend(this.commonQleListTarget.lastElementChild);
    }
    this.thresholdMarkerTarget.classList.toggle('hidden', !this.rareQleListTarget.children.length);
  }
}

/**
 * Sortable wrapper to handle the sorting of two lists in a single instance. Enforces the list sizes when an item is moved between the two lists to ensure
 * static positioning of any intermediate elements (read: our `thresholdMarker` element).
 * 
 * NOTE: This class is a workaround for the lack of native support for sorting fixed-size sublists in a single instance in the Sortable library.
 * While the library does expose an option (`filter` init param) to handle marking some element as "undraggable", it still responds to drags around it.
 * Without this class, dragging elements between the two lists would cause any intermediate elements to be repositioned as if they were sortable elements in the list.
 */
class CrossListSortable {
  /**
   * Creates an instance of CrossListSortable.
   * @param {HTMLElement} primaryList - The DOM element to be made sortable.
   * @param {HTMLElement} secondaryList - Another DOM element to be made sortable.
   * @param {Object} options - The options for the sortable instance.
   */
  constructor(primaryList, secondaryList, options) {
    var currentList = null;
    this.#wrapCallbacks(options, () => currentList, (value) => { currentList = value; });

    this.primaryList = new Sortable(primaryList, options);
    this.secondaryList = new Sortable(secondaryList, options);
  }

  /**
   * Private method to wrap and extend the Sortable callbacks with additional logic supporting the detection of a list cross and subsequent enforcement of list sizes.
   * @param {Object} options - The options object containing the original callbacks.
   * @param {Function} getCurrentList - Function to get the current list.
   * @param {Function} setCurrentList - Function to set the current list.
   */
  #wrapCallbacks(options, getCurrentList, setCurrentList) {
    options.onStart = this.#wrapCallback(options.onStart, (event) => {
      setCurrentList(event.from);
    });

    options.onMove = this.#wrapCallback(options.onMove, (event) => {
      const destinationList = event.to;
      if (getCurrentList() !== destinationList) { // infer list cross when the `destinationList` differs from `currentList`
        setCurrentList(destinationList); // Update `currentList` to the new list to ensure later crosses (including a cross *back* to the original list!) are handled correctly
        this.#fixListSizes(event.dragged, event.related);
        return false; // `#fixListSizes` performs the necessary DOM manipulation itself, so we need to prevent the default behavior
      }
    });

    options.onEnd = this.#wrapCallback(options.onEnd, () => {
      setCurrentList(null);
    });
  }

  /**
   * Private method to wrap a callback with additional functionality.
   * @param {Function} originalCallback - The original callback function.
   * @param {Function} preCallbackHandler - The function to execute before the original callback.
   * @returns {Function} The wrapped callback function.
   */
  #wrapCallback(originalCallback, preCallbackHandler) {
    return (event) => {
      const preCallbackReturn = preCallbackHandler(event) !== false;
      return preCallbackReturn && (!originalCallback || originalCallback(event) !== false);
    };
  }

  /**
   * Handle fixing the original list sizes to ensure intermediate elements are positioned statically when a move event crosses the primary and secondary lists.
   * - When the dragged element is moved into the primary list, it is appended to the primary list and the displaced element is prepended to the secondary list.
   * - When the dragged element is moved into the secondary list, it is prepended to the secondary list and the displaced element is appended to the primary list.
   * @param {HTMLElement} currentElement - The element being dragged.
   * @param {HTMLElement} displacedElement - The element being displaced by the dragged element.
   */
  #fixListSizes(currentElement, displacedElement) {
    const primaryList = this.primaryList.el;
    const secondaryList = this.secondaryList.el;
    const isMoveIntoPrimary = primaryList.contains(displacedElement); // infer the direction of the move based on the current parent of `displacedElement`

    const [primaryElement, secondaryElement] = isMoveIntoPrimary
        ? [currentElement, displacedElement] 
        : [displacedElement, currentElement];

    primaryList.appendChild(primaryElement);
    secondaryList.prepend(secondaryElement);
  }

  /**
   * Get the current order of the combined lists by `data-id`.
   * @returns {Array} The list of concatened primary and secondary ids in the current order.
   */
  toArray() {
    return this.primaryList.toArray().concat(this.secondaryList.toArray())
  }
}

if (!bs4) {
  $( document ).ready(function() {
    $( "#sort_notification_msg .close" ).click(function() {
      $("#sort_notification_msg").hide();
    });
  });
}
