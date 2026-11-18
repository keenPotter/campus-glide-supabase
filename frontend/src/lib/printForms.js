import nvsuLogo from '@/assets/nvsu-logo.png'

// Officers whose names are printed on the form.
// Change the names here if the officers change. This is the only place they are written.
const CHIEF_MOTORPOOL = 'TONY O. BASATAN'
const UNIT_HEAD_GSU = 'JAYSON R. PIMENTEL'

function esc(value) {
  return String(value ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
}

// The logo is embedded in the page so it always prints.
async function logoDataUrl() {
  try {
    const blob = await (await fetch(nvsuLogo)).blob()
    return await new Promise((resolve) => {
      const reader = new FileReader()
      reader.onloadend = () => resolve(reader.result)
      reader.readAsDataURL(blob)
    })
  } catch {
    return null
  }
}

/* ================= Request for Use of Vehicle ================= */

const FORM_CSS = `
  @page { size: 8.5in 14in; margin: 0; }
  * { box-sizing: border-box; }
  html, body { margin: 0; padding: 0; }
  body { font-family: Arial, Helvetica, sans-serif; font-size: 9.5pt; color: #000; }
  p { margin: 0 0 1.6mm; }
  u.strong { font-weight: bold; }
  .u { text-decoration: underline; }
  .sheet { width: 100%; height: 350mm; padding: 6mm 10mm 0; overflow: hidden; }
  .form { height: 172mm; padding: 3mm 2mm 2mm; display: flex; flex-direction: column; overflow: hidden; }
  .form + .form { border-top: 1px dashed #000; }
  .header { width: 100%; border-collapse: collapse; border: 1px solid #000; }
  .header td { border: 1px solid #000; padding: 1mm 2mm; }
  .header .logo { width: 24mm; text-align: center; }
  .header .logo img { width: 17mm; height: 17mm; object-fit: contain; }
  .header .school { text-align: center; font-size: 9pt; line-height: 1.25; }
  .header .name { text-align: center; font-weight: bold; font-size: 11.5pt; padding-top: 2mm; border-top: 1px solid #000; margin-top: 1mm; }
  .ruv { text-align: right; margin: 2mm 0 1mm; }
  .cancelled { border: 1px solid #b91c1c; background: #fee2e2; color: #7f1d1d; padding: 1.5mm 2mm; margin-top: 2mm; font-size: 8.5pt; }
  .grid { display: flex; gap: 4mm; }
  .col-left { flex: 0 0 64%; }
  .col-right { flex: 1 1 auto; }
  .travel { margin-top: 2mm; }
  .hint { padding-left: 10mm; font-size: 8.5pt; }
  .requester-sign { width: 75mm; margin: 2mm auto 0; text-align: center; }
  .sign-name { font-weight: bold; text-decoration: underline; min-height: 12mm; padding-top: 8mm; }
  .sign-label { font-size: 9pt; }
  .rule { border-top: 1px solid #000; margin-top: 4mm; padding-top: 0.5mm; font-size: 9pt; }
  .action-title { text-align: center; font-weight: bold; margin: 1mm 0 3mm; }
  .action-top { display: flex; gap: 4mm; }
  .action-top > div { flex: 1 1 50%; }
  .request { display: flex; gap: 2mm; }
  .request .checks { display: flex; flex-direction: column; gap: 1.5mm; }
  .box { display: inline-block; width: 4.5mm; height: 4.5mm; border: 1px solid #000; text-align: center; line-height: 4.2mm; font-size: 9pt; vertical-align: middle; }
  .blank { display: inline-block; border-bottom: 1px solid #000; height: 4mm; vertical-align: bottom; }
  .action-sign { display: flex; gap: 6mm; margin-top: 3mm; }
  .sig { flex: 1 1 0; text-align: center; }
  .sig .sig-title { text-align: left; margin: 0; }
  .sig .sig-name { margin-top: 9mm; min-height: 5mm; border-bottom: 1px solid #000; font-weight: bold; }
  .sig .sig-role { font-size: 9.5pt; }
  .note { margin-top: auto; font-size: 8.5pt; }
  .note small { font-size: 8pt; }
`

function formCopy(v, logo) {
  const cancelled = v.isCancelled
    ? `<div class="cancelled"><b>CANCELLED</b> · Reason: ${esc(v.cancellationReason || '—')} · By: ${esc(v.cancelledBy || '—')} · ${esc(v.cancelledAt || '')}</div>`
    : ''

  return `
  <section class="form">
    <table class="header"><tr>
      <td class="logo">${logo ? `<img src="${logo}" alt="NVSU logo">` : ''}</td>
      <td>
        <div class="school">Republic of the Philippines<br><b>NUEVA VIZCAYA STATE UNIVERSITY</b><br>Bayombong, Nueva Vizcaya</div>
        <div class="name">REQUEST FOR USE OF VEHICLE</div>
      </td>
    </tr></table>
    <div class="ruv"><b>RUV No.:</b> <u class="strong">${esc(v.ruvNumber)}</u></div>
    ${cancelled}
    <div class="grid">
      <div class="col-left">
        <p><b>Requesting Official:</b> <u class="strong">${esc(v.official)}</u></p>
        <p><b>Position/Designation:</b> <u>${esc(v.position)}</u></p>
        <p><b>Destination/Place(s):</b> <u>${esc(v.destination)}</u></p>
        <p><b>Purpose(s):</b> <u>${esc(v.purpose)}</u></p>
        <p><b>Authorized Passenger(s):</b> <u>${esc(v.passengers)}</u></p>
      </div>
      <div class="col-right">
        <p><b>Request No.:</b> <u>${esc(v.requestNo)}</u></p>
        <p><b>Date Requested:</b> <u>${esc(v.dateRequested)}</u></p>
        <p><b>Time Requested:</b> <u>${esc(v.timeRequested)}</u></p>
      </div>
    </div>
    <div class="grid travel">
      <div class="col-left">
        <p><b>Date of Travel:</b> <u>${esc(v.travelDate)}</u></p>
        <p><b>Days of Travel:</b> <span class="${v.tripType === 'inclusive' ? 'u' : ''}">Inclusive</span>/<span class="${v.tripType === 'exclusive' ? 'u' : ''}">Exclusive</span>: <u>${esc(v.days)}</u></p>
        <p class="hint">(Please underline)</p>
      </div>
      <div class="col-right"><p><b>Time of Travel:</b> <u>${esc(v.departure)}</u></p></div>
    </div>
    <div class="requester-sign">
      <div class="sign-name">${esc(v.official)}</div>
      <div class="sign-label">Name and Signature of Requesting Official</div>
    </div>
    <div class="rule"><i>For the Motorpool only</i></div>
    <div class="action-title">ACTION ON REQUEST</div>
    <div class="action-top">
      <div>
        <p>Vehicle Plate No.: <u>${esc(v.plateNumber)}</u></p>
        <p>Driver: <u>${esc(v.driverName)}</u></p>
      </div>
      <div class="request">
        <span>Request:</span>
        <div class="checks">
          <span><span class="box">&#10003;</span> Approved</span>
          <span><span class="box"></span> Disapproved due to: <span class="blank" style="width:30mm"></span></span>
        </div>
      </div>
    </div>
    <div class="action-sign">
      <div class="sig"><p class="sig-title"><b>Dispatched by:</b></p><div class="sig-name"></div><div class="sig-role">Chief, Mechanic</div></div>
      <div class="sig"><p class="sig-title"><b>Recommending Approval:</b></p><div class="sig-name">${esc(CHIEF_MOTORPOOL)}</div><div class="sig-role">Chief, Motorpool</div></div>
      <div class="sig"><p class="sig-title"><b>Approved:</b></p><div class="sig-name">${esc(UNIT_HEAD_GSU)}</div><div class="sig-role">Unit Head-GSU</div></div>
    </div>
    <div class="note"><i>Note: Please accomplish this form three (3) days before travel.</i><br><small>NVSU-FR-PPS-13-02 (092524)</small></div>
  </section>`
}

export async function buildAllocationFormHtml(v) {
  const logo = await logoDataUrl()
  const copy = formCopy(v, logo)

  return `<!DOCTYPE html><html lang="en"><head><meta charset="utf-8">
<title>Request for Use of Vehicle - #${esc(v.requestNo)}</title><style>${FORM_CSS}</style></head>
<body><div class="sheet">${copy}${copy}</div></body></html>`
}

/* ================= Preventive Maintenance Checklist ================= */

const CHECKLIST_CSS = `
  @page { size: 8.5in 14in; margin: 12mm; }
  * { box-sizing: border-box; }
  body { font-family: Arial, Helvetica, sans-serif; font-size: 10pt; color: #000; margin: 0; }
  h1 { font-size: 13pt; text-align: center; margin: 2mm 0 1mm; }
  .center { text-align: center; font-size: 9pt; line-height: 1.3; }
  table { width: 100%; border-collapse: collapse; margin-top: 4mm; }
  th, td { border: 1px solid #000; padding: 1.5mm 2mm; text-align: left; vertical-align: top; }
  th.c, td.c { text-align: center; width: 20mm; }
  .meta td { border: none; padding: 1mm 0; }
  .box { min-height: 22mm; border: 1px solid #000; padding: 2mm; margin-top: 2mm; white-space: pre-wrap; }
  .label { font-weight: bold; margin-top: 4mm; }
`

export async function buildChecklistHtml(v) {
  const logo = await logoDataUrl()
  const mark = (rating, value) => (rating === value ? '&#10003;' : '')

  const items = v.items
    .map(
      (item) => `<tr><td>${esc(item.label)}</td>
        <td class="c">${mark(item.rating, 'excellent')}</td>
        <td class="c">${mark(item.rating, 'good')}</td>
        <td class="c">${mark(item.rating, 'poor')}</td></tr>`,
    )
    .join('')

  const dates = v.serviceDates
    .map((item) => `<tr><td>${esc(item.label)}</td><td>${esc(item.value) || '&nbsp;'}</td></tr>`)
    .join('')

  return `<!DOCTYPE html><html lang="en"><head><meta charset="utf-8">
<title>Preventive Maintenance Checklist</title><style>${CHECKLIST_CSS}</style></head><body>
  <div class="center">${logo ? `<img src="${logo}" alt="NVSU logo" style="height:16mm"><br>` : ''}
    Republic of the Philippines<br><b>NUEVA VIZCAYA STATE UNIVERSITY</b><br>Bayombong, Nueva Vizcaya</div>
  <h1>PREVENTIVE MAINTENANCE CHECKLIST</h1>
  <table class="meta">
    <tr><td><b>PMUV No.:</b> ${esc(v.pmuvNo)}</td><td><b>Date:</b> ${esc(v.date)}</td></tr>
    <tr><td><b>Vehicle:</b> ${esc(v.vehicleModel)}</td><td><b>Plate No.:</b> ${esc(v.plateNumber)}</td></tr>
    <tr><td><b>Inspector / Mechanic:</b> ${esc(v.inspector)}</td><td><b>Current mileage:</b> ${esc(v.mileage)}</td></tr>
  </table>
  <table><tr><th>Last service</th><th>Date</th></tr>${dates}</table>
  <table><tr><th>Item</th><th class="c">Excellent</th><th class="c">Good</th><th class="c">Poor</th></tr>${items}</table>
  <div class="label">Other parts inspected</div><div class="box">${esc(v.otherParts)}</div>
  <div class="label">Remarks</div><div class="box">${esc(v.remarks)}</div>
  <div class="label">Supervisor's recommendation</div><div class="box">${esc(v.recommendation)}</div>
</body></html>`
}