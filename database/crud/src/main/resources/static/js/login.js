document.getElementById("login-form").addEventListener("submit", async (event) => {
  event.preventDefault();

  const username = document.getElementById("username").value;
  const key = document.getElementById("key").value;
  const errorEl = document.getElementById("error-message");
  errorEl.classList.add("hidden");

  try {
    const response = await fetch("/login", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ username, key })
    });

    if (response.ok) {
      window.location.href = "/index.html";
    } else {
      const data = await response.json().catch(() => ({}));
      errorEl.textContent = data.error || "Invalid data";
      errorEl.classList.remove("hidden");
    }
  } catch (err) {
    errorEl.textContent = "Error with the conection to the server";
    errorEl.classList.remove("hidden");
  }
});