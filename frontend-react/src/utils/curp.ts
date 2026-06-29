// Utilidad para generar los primeros 16 caracteres de la CURP
// Basado en el algoritmo estándar mexicano

const ESTADOS: Record<string, string> = {
  'Aguascalientes': 'AS',
  'Baja California': 'BC',
  'Baja California Sur': 'BS',
  'Campeche': 'CC',
  'Coahuila': 'CL',
  'Colima': 'CM',
  'Chiapas': 'CS',
  'Chihuahua': 'CH',
  'Distrito Federal': 'DF',
  'Ciudad de Mexico': 'DF',
  'Durango': 'DG',
  'Guanajuato': 'GT',
  'Guerrero': 'GR',
  'Hidalgo': 'HG',
  'Jalisco': 'JC',
  'Mexico': 'MC',
  'Michoacan': 'MN',
  'Morelos': 'MS',
  'Nayarit': 'NT',
  'Nuevo Leon': 'NL',
  'Oaxaca': 'OC',
  'Puebla': 'PL',
  'Queretaro': 'QT',
  'Quintana Roo': 'QR',
  'San Luis Potosi': 'SP',
  'Sinaloa': 'SL',
  'Sonora': 'SR',
  'Tabasco': 'TC',
  'Tamaulipas': 'TS',
  'Tlaxcala': 'TL',
  'Veracruz': 'VZ',
  'Yucatan': 'YN',
  'Zacatecas': 'ZS',
  'Extranjero': 'NE'
};

function removeAccents(str: string): string {
  return str.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toUpperCase();
}

function cleanString(str: string): string {
  if (!str) return '';
  return removeAccents(str).trim();
}

function getFirstInternalVowel(str: string): string {
  const vowels = "AEIOU";
  for (let i = 1; i < str.length; i++) {
    if (vowels.includes(str[i])) {
      return str[i];
    }
  }
  return 'X';
}

function getFirstInternalConsonant(str: string): string {
  const vowels = "AEIOU";
  for (let i = 1; i < str.length; i++) {
    if (!vowels.includes(str[i]) && str[i] >= 'A' && str[i] <= 'Z') {
      // Special case for Ñ which is usually mapped to X or handled specifically,
      // but standard standardizes to X or strips it in simple algorithms
      if (str[i] === 'Ñ') return 'X';
      return str[i];
    }
  }
  return 'X';
}

function getCommonName(nombres: string): string {
  const parts = nombres.split(' ');
  // Exclude 'MARIA', 'MA.', 'MA', 'JOSE', 'J.', 'J' if there are multiple names
  if (parts.length > 1) {
    const first = parts[0];
    if (['MARIA', 'MA.', 'MA', 'JOSE', 'J.', 'J'].includes(first)) {
      return parts[1];
    }
  }
  return parts[0] || '';
}

export function generateCURP(
  nombre: string,
  paterno: string,
  materno: string,
  fechaNacimiento: string, // YYYY-MM-DD
  genero: 'H' | 'M',
  estado: string
): string {
  if (!nombre || !paterno || !fechaNacimiento || !genero || !estado) return '';

  const n = cleanString(nombre);
  const p = cleanString(paterno);
  const m = cleanString(materno) || 'X';

  const commonName = getCommonName(n);

  let curp = '';

  // 1-2. Paterno (Primera letra y primera vocal interna)
  curp += p.charAt(0);
  curp += getFirstInternalVowel(p);

  // 3. Materno (Primera letra, o X si no tiene)
  curp += m.charAt(0);

  // 4. Nombre (Primera letra)
  curp += commonName.charAt(0);

  // 5-10. Fecha de nacimiento (YYMMDD)
  const parts = fechaNacimiento.split('-');
  if (parts.length === 3) {
    const yy = parts[0].substring(2);
    const mm = parts[1];
    const dd = parts[2];
    curp += yy + mm + dd;
  } else {
    return '';
  }

  // 11. Sexo
  curp += genero.charAt(0).toUpperCase();

  // 12-13. Entidad Federativa
  const estadoClean = removeAccents(estado);
  curp += ESTADOS[estadoClean] || 'NE';

  // 14. Primera consonante interna de Paterno
  curp += getFirstInternalConsonant(p);

  // 15. Primera consonante interna de Materno
  curp += m === 'X' ? 'X' : getFirstInternalConsonant(m);

  // 16. Primera consonante interna de Nombre
  curp += getFirstInternalConsonant(commonName);

  // Filter out forbidden words (BUEY, CACA, etc)
  const forbidden = ['BACA','BAKA','BUEI','BUEY','CACA','CACO','CAGA','CAGO','CAKA','CAKO','COGE','COGI','COJA','COJE','COJI','COJO','COLA','CULO','FALO','FETO','GETA','GUEI','GUEY','JETA','JOTO','KACA','KACO','KAGA','KAGO','KAKA','KAKO','KOGE','KOGI','KOJA','KOJE','KOJI','KOJO','KOLA','KULO','LILO','LOCA','LOCO','LOKA','LOKO','MAME','MAMI','MAMO','MEAR','MEAS','MEON','MIAR','MION','MOCO','MOKO','MULA','MULO','NACA','NACO','PEDA','PEDO','PENE','PIPI','PITO','POPO','PUTA','PUTO','QULO','RATA','ROBA','ROBE','ROBO','RUIN','SENO','TETA','VACA','VAGA','VAGO','VAKA','VUEI','VUEY','WUEI','WUEY'];
  
  let prefix = curp.substring(0, 4);
  if (forbidden.includes(prefix)) {
    curp = curp.substring(0, 1) + 'X' + curp.substring(2);
  }

  return curp;
}
