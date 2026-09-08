(function checkAuth() {
  const isAuthenticated = localStorage.getItem("is_authenticated") === "true";
  const currentPath = window.location.pathname;

  if (!isAuthenticated && !currentPath.endsWith("login.html") && currentPath !== "/") {
    window.location.replace("/login.html");
  }
})();