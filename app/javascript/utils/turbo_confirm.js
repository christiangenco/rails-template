Turbo.config.forms.confirm = async (message, formElement, submitter) => {
  if (typeof window.showModal === "function") {
    const description =
      submitter?.dataset?.dataConfirmDescription ||
      "This action cannot be undone."
    return window.showModal({
      title: message,
      buttonText: submitter?.textContent?.trim() || "Confirm",
      description: description,
      theme: "danger",
    })
  }
  return window.confirm(message)
}
