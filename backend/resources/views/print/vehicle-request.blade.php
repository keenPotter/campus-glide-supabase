<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Request for Use of Vehicle - #{{ $requestNo }}</title>
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
@for ($copy = 0; $copy < 2; $copy++)
  <section class="form">
    <table class="header">
      <tr>
        <td class="logo">
          @if ($logo)
            <img src="{{ $logo }}" alt="NVSU logo">
          @endif
        </td>
        <td>
          <div class="school">Republic of the Philippines<br><b>NUEVA VIZCAYA STATE UNIVERSITY</b><br>Bayombong, Nueva Vizcaya</div>
          <div class="name">REQUEST FOR USE OF VEHICLE</div>
        </td>
      </tr>
    </table>

    <div class="ruv"><b>RUV No.:</b> <span class="blank w45"></span></div>

    <div class="grid">
      <div class="col-left">
        <p><b>Requesting Official:</b> <u class="strong">{{ $official }}</u></p>
        <p><b>Position/Designation:</b> <u>{{ $position }}</u></p>
        <p><b>Destination/Place(s):</b> <u>{{ $destination }}</u></p>
        <p><b>Purpose(s):</b> <u>{{ $purpose }}</u></p>
        <p><b>Authorized Passenger(s):</b> <u>{{ $passengers }}</u></p>
      </div>
      <div class="col-right">
        <p><b>Request No.:</b> <u>{{ $requestNo }}</u></p>
        <p><b>Date Requested:</b> <u>{{ $dateRequested }}</u></p>
        <p><b>Time Requested:</b> <u>{{ $timeRequested }}</u></p>
      </div>
    </div>

    <div class="grid travel">
      <div class="col-left">
        <p><b>Date of Travel:</b> <u>{{ $travelDate }}</u></p>
        <p><b>Days of Travel:</b> <span class="{{ $tripType === 'inclusive' ? 'u' : '' }}">Inclusive</span>/<span class="{{ $tripType === 'exclusive' ? 'u' : '' }}">Exclusive</span>: <u>{{ $days }}</u></p>
        <p class="hint">(Please underline)</p>
      </div>
      <div class="col-right">
        <p><b>Time of Travel:</b> <u>{{ $departure }}</u></p>
      </div>
    </div>

    <div class="requester-sign">
      <div class="sign-name">{{ $official }}</div>
      <div class="sign-label">Name and Signature of Requesting Official</div>
    </div>

    <div class="rule"><i>For the Motorpool only</i></div>
    <div class="action-title">ACTION ON REQUEST</div>

    <div class="action-top">
      <div>
        {{-- Changed: filled in from the allocation (printing needs an assigned vehicle and driver). --}}
        <p>Vehicle Plate No.: <u>{{ $plateNumber }}</u></p>
        <p>Driver: <u>{{ $driverName }}</u></p>
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
        <div class="sig-name">{{ $chiefMotorpool }}</div>
        <div class="sig-role">Chief, Motorpool</div>
      </div>
      <div class="sig">
        <p class="sig-title"><b>Approved:</b></p>
        <div class="sig-name">{{ $unitHeadGsu }}</div>
        <div class="sig-role">Unit Head-GSU</div>
      </div>
    </div>

    <div class="note">
      <i>Note: Please accomplish this form three (3) days before travel.</i><br>
      <small>NVSU-FR-PPS-13-02 (092524)</small>
    </div>
  </section>
@endfor
</div>
</body>
</html>