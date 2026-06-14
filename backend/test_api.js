async function main() {
  const loginRes = await fetch('http://localhost:3000/api/v1/auth/login', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: 'admin@colegiosandiego.edu.mx', password: 'admin' })
  });
  const { data: { token } } = await loginRes.json();
  const res = await fetch('http://localhost:3000/api/v1/alumnos/16', {
    headers: { 'Authorization': `Bearer ${token}` }
  });
  console.log(await res.json());
}
main();
