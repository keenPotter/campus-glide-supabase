// Prints a full HTML page (for example, a form built by the backend) without showing it.
// The page is loaded into a hidden frame, so only the form is printed, not the rest of the app.
export function printHtml(html) {
  const frame = document.createElement('iframe')
  frame.setAttribute('aria-hidden', 'true')
  frame.style.cssText = 'position:fixed;right:0;bottom:0;width:0;height:0;border:0;'
  document.body.appendChild(frame)

  const cleanup = () => frame.remove()

  frame.addEventListener(
    'load',
    () => {
      const win = frame.contentWindow
      win.addEventListener('afterprint', cleanup, { once: true })
      win.focus()
      win.print()
    },
    { once: true },
  )

  // Safety net in case the print window never reports back.
  setTimeout(cleanup, 120000)

  frame.srcdoc = html
}