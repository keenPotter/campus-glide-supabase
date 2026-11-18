// Creates the first accounts and a few vehicles and drivers.
// Run from the frontend folder:
//   SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... node scripts/seed.mjs
// Every account gets the password "password". Change it after the first sign-in.
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY, {
  auth: { persistSession: false },
})

const users = [
  ['tony.basatan@nvsu.edu.ph', 'Tony', 'Basatan', 'Chief, Motorpool', '09171234501', 'administrator'],
  ['jayson.pimentel@nvsu.edu.ph', 'Jayson', 'Pimentel', 'Unit Head-GSU', '09171234502', 'administrator'],
  ['reonel.makil@nvsu.edu.ph', 'Reonel', 'Makil', 'Motorpool Staff', '09171234503', 'staff'],
  ['wilfredo.dumale@nvsu.edu.ph', 'Wilfredo', 'Dumale Jr.', 'University President', '09201234510', 'faculty'],
  ['marife.aliaga@nvsu.edu.ph', 'Marife', 'Aliaga', 'Professor', '09201234503', 'faculty'],
  ['krizsha.salinas@nvsu.edu.ph', 'Krizsha Ellaine', 'Salinas', 'Instructor', '09201234505', 'faculty'],
]

for (const [email, first_name, last_name, position, phone_number, role] of users) {
  const { data, error } = await supabase.auth.admin.createUser({ email, password: 'password', email_confirm: true })
  if (error) {
    console.log(`Skipped ${email}: ${error.message}`)
    continue
  }
  const { error: profileError } = await supabase
    .from('profiles')
    .insert({ auth_id: data.user.id, email, first_name, last_name, position, phone_number, role })
  console.log(profileError ? `Profile failed for ${email}: ${profileError.message}` : `Created ${role}: ${email}`)
}

const day = (n) => new Date(Date.now() + n * 86400000).toISOString().slice(0, 10)

await supabase.from('vehicles').insert([
  { plate_number: 'SAA 1234', vehicle_model: 'Toyota Hiace Commuter', vehicle_type: 'Van', capacity: 15 },
  { plate_number: 'NBC 5521', vehicle_model: 'Toyota Innova', vehicle_type: 'MPV', capacity: 7 },
  { plate_number: 'AEF 6098', vehicle_model: 'Toyota Vios', vehicle_type: 'Sedan', capacity: 4 },
  { plate_number: 'NLM 8830', vehicle_model: 'Toyota Fortuner', vehicle_type: 'SUV', capacity: 7 },
])

await supabase.from('drivers').insert([
  { first_name: 'Juan', last_name: 'Reyes', license_number: 'N02-19-012345', license_expiry_date: day(565), contact_number: '09181234503' },
  { first_name: 'Pedro', last_name: 'Bautista', license_number: 'N02-17-067890', license_expiry_date: day(400), contact_number: '09181234504' },
  { first_name: 'Ernesto', last_name: 'Villanueva', license_number: 'N02-20-045678', license_expiry_date: day(850), contact_number: '09181234506' },
  { first_name: 'Armando', last_name: 'Cabrera', license_number: 'N02-21-056789', license_expiry_date: day(1100), contact_number: '09181234508' },
])

console.log('Seed finished.')