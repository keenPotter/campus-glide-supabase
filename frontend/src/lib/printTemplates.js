import nvsuLogo from "@/assets/nvsu-logo.png";

// The two printable forms. They were Blade views in the Laravel app (resources/views/print).
// The backend now sends only the values (get_vehicle_request_print / get_checklist_print),
// and these functions turn them into the same HTML pages.

const esc = (value) =>
  String(value ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");

// The form is shown in a frame without its own address, so the logo needs a full URL.
function logoUrl() {
  try {
    return new URL(nvsuLogo, window.location.href).href;
  } catch {
    return "";
  }
}

/* ================= REQUEST FOR USE OF VEHICLE ================= */

function requestCopy(d, logo) {
  return `
  <section class="form">
    <table class="header">
      <tr>
        <td class="logo">${logo ? `<img src="${esc(logo)}" alt="NVSU logo">` : ""}</td>
        <td>
          <div class="school">Republic of the Philippines<br><b>NUEVA VIZCAYA STATE UNIVERSITY</b><br>Bayombong, Nueva Vizcaya</div>
          <div class="name">REQUEST FOR USE OF VEHICLE</div>
        </td>
      </tr>
    </table>
    
    <div class="ruv"><b>RUV No.:</b> ${d.ruvNumber ? `<u class="strong">${esc(d.ruvNumber)}</u>` : '<span class="blank w45"></span>'}</div>

    <div class="grid">
      <div class="col-left">
        <p><b>Requesting Official:</b> <u class="strong">${esc(d.official)}</u></p>
        <p><b>Position/Designation:</b> <u>${esc(d.position)}</u></p>
        <p><b>Destination/Place(s):</b> <u>${esc(d.destination)}</u></p>
        <p><b>Purpose(s):</b> <u>${esc(d.purpose)}</u></p>
        <p><b>Authorized Passenger(s):</b> <u>${esc(d.passengers)}</u></p>
      </div>
      <div class="col-right">
        <p><b>Request No.:</b> <u>${esc(d.requestNo)}</u></p>
        <p><b>Date Requested:</b> <u>${esc(d.dateRequested)}</u></p>
        <p><b>Time Requested:</b> <u>${esc(d.timeRequested)}</u></p>
      </div>
    </div>

    <div class="grid travel">
      <div class="col-left">
        <p><b>Date of Travel:</b> <u>${esc(d.travelDate)}</u></p>
        <p><b>Days of Travel:</b> <span class="${d.tripType === "inclusive" ? "u" : ""}">Inclusive</span>/<span class="${d.tripType === "exclusive" ? "u" : ""}">Exclusive</span>: <u>${esc(d.days)}</u></p>
        <p class="hint">(Please underline)</p>
      </div>
      <div class="col-right">
        <p><b>Time of Travel:</b> <u>${esc(d.departure)}</u></p>
      </div>
    </div>

    <div class="requester-sign">
      <div class="sign-name">${esc(d.official)}</div>
      <div class="sign-label">Name and Signature of Requesting Official</div>
    </div>

    <div class="rule"><i>For the Motorpool only</i></div>
    <div class="action-title">ACTION ON REQUEST</div>

    <div class="action-top">
      <div>
        <p>Vehicle Plate No.: <u>${esc(d.plateNumber)}</u></p>
        <p>Driver: <u>${esc(d.driverName)}</u></p>
      </div>
      <div class="request">
        <span>Request:</span>
        <div class="checks">
          <span class="check"><span class="box">&#10003;</span> Approved</span>
          <span class="check"><span class="box"></span> Disapproved due to: <span class="blank w30"></span></span>
        </div>
      </div>
    </div>

    <div class="action-sign">
      <div class="sig">
        <p class="sig-title"><b>Dispatched by:</b></p>
        <div class="sig-name"></div>
        <div class="sig-role">Chief, Mechanic</div>
      </div>
      <div class="sig">
        <p class="sig-title"><b>Recommending Approval:</b></p>
        <div class="sig-name">${esc(d.chiefMotorpool)}</div>
        <div class="sig-role">Chief, Motorpool</div>
      </div>
      <div class="sig">
        <p class="sig-title"><b>Approved:</b></p>
        <div class="sig-name">${esc(d.unitHeadGsu)}</div>
        <div class="sig-role">Unit Head-GSU</div>
      </div>
    </div>

    <div class="note">
      <i>Note: Please accomplish this form three (3) days before travel.</i><br>
      <small>NVSU-FR-PPS-13-02 (092524)</small>
    </div>
  </section>`;
}

export function vehicleRequestHtml(d) {
  const logo = logoUrl();

  return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Request for Use of Vehicle - #${esc(d.requestNo)}</title>
<style>
  /* Legal size, no browser margin (this also removes the date/URL header and footer). */
  @page { size: 8.5in 14in; margin: 0; }
  * { box-sizing: border-box; }
  html, body { margin: 0; padding: 0; }
  body { font-family: Arial, Helvetica, sans-serif; font-size: 9.5pt; color: #000; }
  p { margin: 0 0 1.6mm; }
  u { text-decoration: underline; }
  u.strong { font-weight: bold; }
  .u { text-decoration: underline; }

  /* One Legal page holds two copies of the form, one on top of the other. */
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
  .blank { display: inline-block; border-bottom: 1px solid #000; height: 4mm; vertical-align: bottom; }
  .w30 { width: 30mm; } .w45 { width: 45mm; } .w55 { width: 55mm; } .w65 { width: 65mm; }

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
  .check { display: block; }
  .box { display: inline-block; width: 4.5mm; height: 4.5mm; border: 1px solid #000; text-align: center; line-height: 4.2mm; font-size: 9pt; vertical-align: middle; }

  /* Three signature areas in one row, all lined up the same way. */
  .action-sign { display: flex; gap: 6mm; margin-top: 3mm; }
  .sig { flex: 1 1 0; text-align: center; }
  .sig .sig-title { text-align: left; margin: 0; }
  .sig .sig-name { margin-top: 9mm; min-height: 5mm; border-bottom: 1px solid #000; font-weight: bold; }
  .sig .sig-role { font-size: 9.5pt; }

  .note { margin-top: auto; font-size: 8.5pt; }
  .note small { font-size: 8pt; }
</style>
</head>
<body>
<div class="sheet">
${requestCopy(d, logo)}
${requestCopy(d, logo)}
</div>
</body>
</html>`;
}

/* ================= PREVENTIVE MAINTENANCE CHECKLIST ================= */

export function checklistHtml(d) {
  const serviceDates = (d.serviceDates ?? [])
    .map(
      (service) =>
        `<td><span>${esc(service.label)}</span><strong>${esc(service.value)}</strong></td>`,
    )
    .join("");

  const mark = (item, rating) =>
    item.rating === rating ? "&#10003;" : "&nbsp;";

  const items = (d.items ?? [])
    .map(
      (item) => `
        <tr>
          <th scope="row">${esc(item.label)}</th>
          <td class="rating">${mark(item, "excellent")}</td>
          <td class="rating">${mark(item, "good")}</td>
          <td class="rating">${mark(item, "poor")}</td>
        </tr>`,
    )
    .join("");

  return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Preventive Maintenance Checklist - ${esc(d.plateNumber)}</title>
<style>
  /* Legal size, no browser margin (this also removes the date/URL header and footer). */
  @page { size: 8.5in 14in; margin: 0; }
  * { box-sizing: border-box; }
  html, body { margin: 0; padding: 0; }
  body { font-family: Arial, Helvetica, sans-serif; font-size: 10pt; color: #111; }
  h1, h2, p { margin: 0; }
  .page { padding: 12mm 14mm; }

  .heading { border-bottom: 2px solid #111; padding-bottom: 2mm; text-align: center; }
  .heading .university { font-size: 11pt; font-weight: 700; }
  .heading .title { font-size: 13pt; font-weight: 700; margin-top: 1.5mm; }

  .topline { display: flex; justify-content: space-between; margin: 3mm 0 2mm; }

  table { border-collapse: collapse; width: 100%; page-break-inside: avoid; }
  .vehicle { margin-bottom: 2mm; }
  .vehicle td { border: 1px solid #333; height: 9mm; padding: 1mm 2mm; width: 50%; }
  .label { color: #333; font-size: 8pt; font-weight: 700; }

  .section-title { font-size: 9pt; margin: 2mm 0 1mm; }

  .service-dates td { border: 1px solid #555; padding: 1mm 2mm; width: 20%; }
  .service-dates span, .service-dates strong { display: block; }
  .service-dates span { font-size: 8pt; }
  .service-dates strong { margin-top: 1mm; min-height: 4mm; }

  .items { table-layout: fixed; }
  .items th, .items td { border: 1px solid #333; padding: 1.2mm 2mm; }
  .items thead th { background: #f1f1f1; text-align: center; }
  .items th:first-child { text-align: left; width: 55%; }
  .items .rating { text-align: center; width: 15%; }

  /* Tall boxes so there is room to write. */
  .box { border: 1px solid #333; min-height: 26mm; padding: 2mm 3mm; white-space: pre-wrap; page-break-inside: avoid; }

  .signatures { display: flex; gap: 12mm; margin-top: 14mm; }
  .signature { flex: 1 1 0; border-top: 1px solid #333; padding-top: 1mm; text-align: center; }
  .signature small { display: block; margin-top: 0.5mm; }

  @media print { body { -webkit-print-color-adjust: exact; print-color-adjust: exact; } }
</style>
</head>
<body>
<div class="page">
  <header class="heading">
    <p>Republic of the Philippines</p>
    <p class="university">NUEVA VIZCAYA STATE UNIVERSITY</p>
    <p>Bayombong, Nueva Vizcaya</p>
    <h1 class="title">PREVENTIVE MAINTENANCE CHECKLIST OF UNIVERSITY VEHICLES</h1>
  </header>

  <div class="topline">
    <span><b>PMUV No.:</b> ${esc(d.pmuvNo)}</span>
    <span><b>Date:</b> ${esc(d.date)}</span>
  </div>

  <table class="vehicle">
    <tbody>
      <tr>
        <td><span class="label">Vehicle / Make and model</span><br>${esc(d.vehicleModel)}</td>
        <td><span class="label">Plate number</span><br>${esc(d.plateNumber)}</td>
      </tr>
      <tr>
        <td><span class="label">Inspector / Mechanic</span><br>${esc(d.inspector)}</td>
        <td><span class="label">Current mileage</span><br>${esc(d.mileage)}</td>
      </tr>
    </tbody>
  </table>

  <h2 class="section-title">Last service dates</h2>
  <table class="service-dates">
    <tbody>
      <tr>${serviceDates}</tr>
    </tbody>
  </table>

  <h2 class="section-title">Vehicle condition (check one for each item)</h2>
  <table class="items">
    <thead>
      <tr><th>Item</th><th>Excellent</th><th>Good</th><th>Poor</th></tr>
    </thead>
    <tbody>${items}
    </tbody>
  </table>

  <h2 class="section-title">Other parts inspected</h2>
  <div class="box">${esc(d.otherParts)}</div>

  <h2 class="section-title">Remarks</h2>
  <div class="box">${esc(d.remarks)}</div>

  <h2 class="section-title">Supervisor's recommendation</h2>
  <div class="box">${esc(d.recommendation)}</div>

  <div class="signatures">
    <div class="signature">${esc(d.inspector)}<small>Inspector / Mechanic</small></div>
    <div class="signature"><small>Supervisor</small></div>
  </div>
</div>
</body>
</html>`;
}
