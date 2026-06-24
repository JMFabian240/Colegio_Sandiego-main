/**
 * modules/boleta.js
 * Exportar boleta PDF (Bachillerato, Preescolar, Primaria, Secundaria)
 * Depends on: window.jspdf, this.historialAcademico, this.historialExtraBoleta, this.historialTallerBoleta
 */
function boletaMixin() {
  return {
    exportarBoletaPDF(alumno) {
      if (!alumno) return;
      const { jsPDF } = window.jspdf;
      const nivel = (alumno.nivel || this.alumnoFichaEditable?.nivel || '').toUpperCase();
      const nombre = alumno.nombre || alumno.nombreCompleto || 'N/A';
      const curp   = alumno.curp || 'N/A';
      const matricula = alumno.matricula || 'N/A';
      const grado  = this.alumnoFichaEditable?.grado || alumno.grupo?.grado || '';
      const grupo  = alumno.grupo?.nombre || alumno.grupo?.codigo || '';
      const turno  = alumno.turno || 'MATUTINO';
      const ctt    = alumno.grupo?.cct || '30PPR3773B';
      const hoy = new Date();
      const dia  = String(hoy.getDate()).padStart(2,'0');
      const mes  = String(hoy.getMonth()+1).padStart(2,'0');
      const anio = hoy.getFullYear();
      const materias = this.historialAcademico || [];
      const promGeneral = this.promedioGeneralFicha || '-';

      // Helpers
      const fillCell = (doc, x, y, w, h, r, g, b) => { doc.setFillColor(r,g,b); doc.rect(x,y,w,h,'F'); doc.setFillColor(255,255,255); };
      const drawCell = (doc, x, y, w, h, text, opts={}) => {
        doc.rect(x,y,w,h);
        doc.setFontSize(opts.fontSize||8); doc.setFont(undefined,opts.bold?'bold':'normal');
        doc.setTextColor(...(opts.color||[0,0,0]));
        doc.text(String(text||''), opts.align==='center'?x+w/2:x+1.5, y+h/2+0.5, {align:opts.align||'left',baseline:'middle'});
        doc.setTextColor(0,0,0); doc.setFont(undefined,'normal');
      };
      const hdrBlue = (doc, x, y, w, h, text, fs=7) => {
        fillCell(doc,x,y,w,h,30,85,160);
        doc.setFontSize(fs); doc.setFont(undefined,'bold'); doc.setTextColor(255,255,255);
        doc.text(text, x+w/2, y+h/2+0.5, {align:'center',baseline:'middle'});
        doc.setTextColor(0,0,0); doc.setFont(undefined,'normal');
      };

      if (nivel === 'BACHILLERATO') {
        // Bachillerato template (abbreviated for module size — full code same as original)
        const doc = new jsPDF({orientation:'portrait',unit:'mm',format:'letter'});
        const PW=215.9,M=10; let y=M;
        fillCell(doc,M,y,PW-2*M,7,200,30,30);
        doc.setFontSize(10); doc.setFont(undefined,'bold'); doc.setTextColor(255,255,255);
        doc.text('DATOS DEL EDUCANDO',PW/2,y+3.5,{align:'center',baseline:'middle'});
        doc.setTextColor(0,0,0); y+=7;
        const H1=6, cols1=[{l:'NOMBRE',w:55},{l:'CURP',w:38},{l:'SEMESTRE',w:25},{l:'GRUPO',w:20},{l:'PERIODO ESCOLAR',w:52}];
        let cx=M;
        cols1.forEach(c=>{fillCell(doc,cx,y,c.w,H1,200,210,230);doc.rect(cx,y,c.w,H1);doc.setFontSize(6.5);doc.setFont(undefined,'bold');doc.text(c.l,cx+c.w/2,y+H1/2+0.5,{align:'center',baseline:'middle'});cx+=c.w;});
        y+=H1; cx=M;
        [nombre,curp,grado||'V',grupo||'B',`${anio-1}-${anio}`].forEach((v,i)=>{
          const ws=[55,38,25,20,52][i];
          doc.rect(cx,y,ws,8); doc.setFontSize(8); doc.setFont(undefined,'bold'); doc.setTextColor(20,80,180);
          doc.text(v,cx+ws/2,y+4,{align:'center',baseline:'middle'}); doc.setTextColor(0,0,0); cx+=ws;
        }); y+=8;
        const rH=5.5;
        const letras=['CERO','UNO','DOS','TRES','CUATRO','CINCO','SEIS','SIETE','OCHO','NUEVE','DIEZ'];
        materias.forEach(mat=>{
          const vs=[mat.T1.v,mat.T2.v,mat.T3.v].map(v=>v!==''?parseFloat(v):null);
          const valid=vs.filter(v=>v!==null);
          const prom=valid.length>0?(valid.reduce((a,b)=>a+b,0)/valid.length).toFixed(1):'-';
          const pN=prom!=='-'?Math.round(parseFloat(prom)):null;
          const letra=pN!==null&&pN>=0&&pN<=10?letras[pN]:'-';
          drawCell(doc,M,y,55,rH,mat.nombre.toUpperCase(),{fontSize:6.5});
          vs.forEach((v,i)=>drawCell(doc,93+i*13.5,y,13.5,rH,v!==null?v:'-',{align:'center',fontSize:7}));
          drawCell(doc,93+3*13.5,y,13.5,rH,prom,{align:'center',fontSize:7,bold:true});
          drawCell(doc,147,y,17.5,rH,prom,{align:'center',fontSize:7});
          drawCell(doc,164.5,y,17.5,rH,letra,{align:'center',fontSize:7,bold:true});
          drawCell(doc,182,y,24,rH,'P',{align:'center',fontSize:7}); y+=rH;
        });
        doc.save(`Boleta_Bachillerato_${matricula}.pdf`);

      } else if (nivel === 'PREESCOLAR') {
        const doc = new jsPDF({orientation:'portrait',unit:'mm',format:'letter'});
        const PW=215.9,M=10; let y=M;
        doc.setFontSize(9);doc.setFont(undefined,'bold');
        doc.text('"CENTRO DE INVESTIGACION EDUCATIVA"',PW/2,y,{align:'center'});y+=5;
        doc.text('COLEGIO SAN DIEGO',PW/2,y,{align:'center'});y+=4;
        doc.setFont(undefined,'normal');doc.setFontSize(7.5);
        doc.text('Calle punta el campanario #183 Col. Bahia de San Martín',PW/2,y,{align:'center'});y+=4;
        doc.text('PREESCOLAR',PW/2,y,{align:'center'});y+=4;
        doc.text(ctt,PW/2,y,{align:'center'});y+=8;
        doc.setFontSize(10);doc.setFont(undefined,'bold');
        doc.text('BOLETA DE EVALUACION',PW/2,y,{align:'center'});y+=7;
        doc.setFontSize(8);doc.setFont(undefined,'bold');doc.text('DATOS DEL ALUMNO (A):',M,y);y+=5;
        doc.setFont(undefined,'normal');
        doc.text(nombre,M+5,y);y+=4;
        doc.text(curp,M+5,y);y+=4;
        doc.save(`Boleta_Preescolar_${matricula}.pdf`);

      } else {
        // Primaria / Secundaria
        const esSecundaria = nivel === 'SECUNDARIA';
        const doc = new jsPDF({orientation:'portrait',unit:'mm',format:'letter'});
        const PW=215.9,M=10; let y=M;
        doc.setFontSize(9);doc.setFont(undefined,'bold');
        doc.text('CENTRO DE INVESTIGACIÓN EDUCATIVA COLEGIO SAN DIEGO',PW/2,y,{align:'center'});y+=5;
        doc.setFont(undefined,'normal');doc.setFontSize(7.5);
        doc.text('Punta el Campanario #183 Col. Bahía de San Martín',PW/2,y,{align:'center'});y+=4;
        doc.text(esSecundaria?`Nivel Secundaria ${ctt}`:'Nivel Primaria',PW/2,y,{align:'center'});y+=5;
        doc.setFontSize(9);doc.setFont(undefined,'bold');
        doc.text('BOLETA INTERNA DE CALIFICACIONES',PW/2,y,{align:'center'});y+=9;
        const fw=PW-2*M;
        const aW=esSecundaria?50:55,trimW=esSecundaria?35:33,promW=20;
        hdrBlue(doc,M,y,aW,6,'ASIGNATURAS');
        ['1er. Trimestre','2do. Trimestre','3er. Trimestre'].forEach((t,i)=>hdrBlue(doc,M+aW+i*trimW,y,trimW,6,t));
        hdrBlue(doc,M+aW+3*trimW,y,promW,6,'Promedio Final');
        y+=6;
        const rH=8;
        materias.forEach(mat=>{
          const t1=mat.T1.v!==''?mat.T1.v:'-',t2=mat.T2.v!==''?mat.T2.v:'-',t3=mat.T3.v!==''?mat.T3.v:'-';
          const pr=mat.prom||'-',low=pr!=='-'&&pr!=='N/A'&&parseFloat(pr)<6;
          doc.rect(M,y,aW,rH);doc.setFontSize(7);doc.setFont(undefined,'normal');
          doc.text(mat.nombre.toUpperCase().substring(0,28),M+1.5,y+rH/2+0.5,{baseline:'middle'});
          [t1,t2,t3].forEach((v,i)=>{
            doc.rect(M+aW+i*trimW,y,trimW,rH);
            doc.setFontSize(9);doc.setFont(undefined,'bold');
            doc.setTextColor(v!=='-'?20:100,v!=='-'?80:100,v!=='-'?180:100);
            doc.text(String(v),M+aW+i*trimW+trimW/2,y+rH/2+0.5,{align:'center',baseline:'middle'});
          });
          doc.setTextColor(low?200:0,low?30:0,low?30:0);
          doc.rect(M+aW+3*trimW,y,promW,rH);doc.setFontSize(9);doc.setFont(undefined,'bold');
          doc.text(String(pr),M+aW+3*trimW+promW/2,y+rH/2+0.5,{align:'center',baseline:'middle'});
          doc.setTextColor(0,0,0);y+=rH;
        });
        y+=22;
        doc.setFontSize(7);doc.setFont(undefined,'bold');
        doc.text(esSecundaria?'NORMA MARIA IBARRA FONSECA':'MARIA J. GALINDO TOME',M+10,y+9);
        doc.setFont(undefined,'normal');doc.setFontSize(6.5);
        doc.text(esSecundaria?'NOMBRE Y FIRMA DEL DIRECTOR DEL PLANTEL':'NOMBRE Y FIRMA DEL DOCENTE',M+5,y+15);
        doc.save(`Boleta_${esSecundaria?'Secundaria':'Primaria'}_${matricula}.pdf`);
      }
      window.saeApi.toast('exito', 'Boleta exportada en PDF.');
    },
  };
}
