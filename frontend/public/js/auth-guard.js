(function checkAuth() {
  const isAuthenticated = localStorage.getItem("is_authenticated") === "true";
  const currentPath = window.location.pathname;

  // if not loged and tries to access, redirects to login
  if (!isAuthenticated && !currentPath.endsWith("login.html") && currentPath !== "/") {
    window.location.replace("/login.html");
  } 
  else if (isAuthenticated && (currentPath.endsWith("login.html") || currentPath === "/")) {
    window.location.replace("/index.html");
  }
})();