<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Preventive Maintenance Checklist - {{ $plateNumber }}</title>
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
    <span><b>PMUV No.:</b> {{ $pmuvNo }}</span>
    <span><b>Date:</b> {{ $date }}</span>
  </div>

  <table class="vehicle">
    <tbody>
      <tr>
        <td><span class="label">Vehicle / Make and model</span><br>{{ $vehicleModel }}</td>
        <td><span class="label">Plate number</span><br>{{ $plateNumber }}</td>
      </tr>
      <tr>
        <td><span class="label">Inspector / Mechanic</span><br>{{ $inspector }}</td>
        <td><span class="label">Current mileage</span><br>{{ $mileage }}</td>
      </tr>
    </tbody>
  </table>

  <h2 class="section-title">Last service dates</h2>
  <table class="service-dates">
    <tbody>
      <tr>
        @foreach ($serviceDates as $service)
          <td><span>{{ $service['label'] }}</span><strong>{{ $service['value'] }}</strong></td>
        @endforeach
      </tr>
    </tbody>
  </table>

  <h2 class="section-title">Vehicle condition (check one for each item)</h2>
  <table class="items">
    <thead>
      <tr><th>Item</th><th>Excellent</th><th>Good</th><th>Poor</th></tr>
    </thead>
    <tbody>
      @foreach ($items as $item)
        <tr>
          <th scope="row">{{ $item['label'] }}</th>
          <td class="rating">{!! $item['rating'] === 'excellent' ? '&#10003;' : '&nbsp;' !!}</td>
          <td class="rating">{!! $item['rating'] === 'good' ? '&#10003;' : '&nbsp;' !!}</td>
          <td class="rating">{!! $item['rating'] === 'poor' ? '&#10003;' : '&nbsp;' !!}</td>
        </tr>
      @endforeach
    </tbody>
  </table>

  <h2 class="section-title">Other parts inspected</h2>
  <div class="box">{{ $otherParts }}</div>

  <h2 class="section-title">Remarks</h2>
  <div class="box">{{ $remarks }}</div>

  <h2 class="section-title">Supervisor's recommendation</h2>
  <div class="box">{{ $recommendation }}</div>

  <div class="signatures">
    <div class="signature">{{ $inspector }}<small>Inspector / Mechanic</small></div>
    <div class="signature"><small>Supervisor</small></div>
  </div>
</div>
</body>
</html>