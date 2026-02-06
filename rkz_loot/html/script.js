window.addEventListener("message", function (event) {
  if (event.data.action === "startProgress") {
    const container = document.getElementById("progress-container");
    const fill = document.getElementById("fill");

    container.style.display = "block";
    fill.style.transition = "none";
    fill.style.width = "0%";

    setTimeout(() => {
      fill.style.transition = `width ${event.data.duration}ms linear`;
      fill.style.width = "100%";
    }, 50);

    setTimeout(() => {
      container.style.display = "none";
      fetch(`https://${GetParentResourceName()}/progressComplete`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({})
      });
    }, event.data.duration);
  }
});
window.addEventListener("message", function (event) {
  if (event.data.action === "debug") {
    document.body.innerHTML = "<h1 style='color:red;'>DEBUG MODE ACTIVE</h1>";
  }
});

