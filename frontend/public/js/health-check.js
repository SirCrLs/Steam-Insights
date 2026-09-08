document.addEventListener("DOMContentLoaded", () => {
  const services = [
    { cardId: "card-crud", badgeId: "badge-crud" },
    { cardId: "card-dashboard", badgeId: "badge-dashboard" },
    { cardId: "card-ml", badgeId: "badge-ml" }
  ];

  services.forEach(service => checkServiceHealth(service.cardId, service.badgeId));
});

async function checkServiceHealth(cardId, badgeId) {
  const badge = document.getElementById(badgeId);
  const card = document.getElementById(cardId);
  if (!badge || !card) return;

  const endpoint = badge.getAttribute("data-endpoint");
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), 3000);

  try {
    const response = await fetch(endpoint, { 
      method: "GET",
      signal: controller.signal 
    });
    clearTimeout(timeoutId);

    if (response.ok) {
      setCardStatus(card, badge, true, "Available");
    } else {
      setCardStatus(card, badge, false, "Unavailable");
    }
  } catch (error) {
    clearTimeout(timeoutId);
    setCardStatus(card, badge, false, "Disabled");
  }
}

function setCardStatus(card, badge, isOnline, text) {
  badge.textContent = text;

  if (isOnline) {
    badge.className = "badge status-online";
    card.classList.remove("disabled");
    card.classList.add("active");
    card.style.pointerEvents = "auto";
  } else {
    badge.className = "badge status-offline";
    card.classList.remove("active");
    card.classList.add("disabled");
    card.style.pointerEvents = "none";
  }
}