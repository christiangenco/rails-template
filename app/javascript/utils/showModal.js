import Alpine from "alpinejs"

Alpine.store("modal", {
  isOpen: false,
  title: "",
  description: "",
  buttonText: "",
  theme: "primary",
  resolve: null,

  show({ title, description, buttonText, theme = "primary" }) {
    this.title = title
    this.description = description
    this.buttonText = buttonText
    this.theme = theme
    this.isOpen = true

    return new Promise((resolve) => {
      this.resolve = resolve
    })
  },

  confirm() {
    this.isOpen = false
    if (this.resolve) {
      this.resolve(true)
      this.resolve = null
    }
  },

  cancel() {
    this.isOpen = false
    if (this.resolve) {
      this.resolve(false)
      this.resolve = null
    }
  },
})

export default function showModal(options) {
  return Alpine.store("modal").show(options)
}
