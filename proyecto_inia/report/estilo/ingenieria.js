(function () {
  "use strict";

  var NS = "http://www.w3.org/2000/svg";
  // Las animaciones quedan activas salvo que el lector las apague con el botón (se recuerda la elección).
  var CLAVE = "informe-animaciones";
  var movimiento = (function () {
    try { return localStorage.getItem(CLAVE) !== "no"; } catch (e) { return true; }
  })();
  var reduceMotion = !movimiento;
  if (movimiento) document.documentElement.classList.add("movimiento");

  function texto(el) { return (el.textContent || "").replace(/\s+/g, " ").trim(); }

  // "−985,9" -> -985.9 ; "3.729" -> 3729 ; devuelve NaN si no es un número
  function numero(s) {
    var t = String(s).trim().replace(/−/g, "-");
    if (!/^-?[\d.]+(,\d+)?$/.test(t)) return NaN;
    return parseFloat(t.replace(/\./g, "").replace(",", "."));
  }

  function el(tag, cls, html) {
    var e = document.createElement(tag);
    if (cls) e.className = cls;
    if (html != null) e.innerHTML = html;
    return e;
  }

  /* ---------- Portada ---------- */
  function armarPortada() {
    var banner = document.querySelector("#title-block-header .quarto-title-banner");
    if (!banner) return;
    var cont = banner.querySelector(".quarto-title");
    var h1 = banner.querySelector("h1.title");
    var sub = banner.querySelector(".subtitle");
    if (!cont || !h1) return;

    var portada = el("div", "portada");
    var curso = null;
    var meta = [];

    if (sub) {
      sub.innerHTML.split(/<br\s*\/?>/i).forEach(function (parte) {
        var m = parte.match(/^\s*<strong>([^<]+?):?\s*<\/strong>:?\s*([\s\S]*)$/i);
        if (m) meta.push([m[1].replace(/:$/, "").trim(), m[2].trim()]);
        else if (parte.trim() && !curso) curso = parte.trim();
      });
    }

    if (curso) portada.appendChild(el("p", "portada-curso", curso));

    var rango = h1.innerHTML.match(/^([\s\S]*?)\s*\(([^()]+)\)\s*$/);
    if (rango) h1.innerHTML = rango[1] + '<span class="titulo-rango">' + rango[2] + "</span>";
    portada.appendChild(h1);

    var desc = document.querySelector('meta[name="description"]');
    var pregunta = desc && desc.getAttribute("content");
    if (pregunta) portada.appendChild(el("p", "portada-pregunta", pregunta));

    if (meta.length) {
      var dl = el("dl", "portada-meta");
      meta.forEach(function (par) {
        var d = el("div");
        d.appendChild(el("dt", null, par[0]));
        d.appendChild(el("dd", null, par[1]));
        dl.appendChild(d);
      });
      portada.appendChild(dl);
    }

    cont.innerHTML = "";
    cont.appendChild(portada);

    var notas = el("div", "portada-notas");
    notas.setAttribute("aria-hidden", "true");
    notas.innerHTML =
      '<span class="nota-p"><b>P</b>precipitación<span class="flecha">↓</span></span>' +
      '<span class="nota-et"><b>ET₀</b>evapotranspiración<span class="flecha">↑</span></span>';
    banner.appendChild(notas);

    var sol = el("div", "sol");
    sol.setAttribute("aria-hidden", "true");
    banner.appendChild(sol);

    dividirPalabras(h1);
    lluvia(banner);
  }

  function dividirPalabras(h1) {
    var n = 0;
    h1.setAttribute("aria-label", texto(h1));
    Array.prototype.slice.call(h1.childNodes).forEach(function (nodo) {
      if (nodo.nodeType !== 3) return;
      var frag = document.createDocumentFragment();
      nodo.textContent.split(/(\s+)/).forEach(function (p) {
        if (!p) return;
        if (/^\s+$/.test(p)) { frag.appendChild(document.createTextNode(" ")); return; }
        var w = el("span", "palabra");
        w.setAttribute("aria-hidden", "true");
        var s = el("span");
        s.textContent = p;
        s.style.setProperty("--n", n++);
        w.appendChild(s);
        frag.appendChild(w);
      });
      h1.replaceChild(frag, nodo);
    });
  }

  // Lluvia sobre el lado de la tormenta de la foto de portada
  function lluvia(banner) {
    if (reduceMotion) return;
    var c = el("canvas", "lluvia");
    c.setAttribute("aria-hidden", "true");
    var ctx = c.getContext && c.getContext("2d");
    if (!ctx) return;
    banner.appendChild(c);

    var gotas = [], w = 0, h = 0, activo = false, raf = 0, viento = 0.17;
    var dpr = Math.min(window.devicePixelRatio || 1, 2);

    function nueva(cualquierAltura) {
      return {
        x: Math.random() * w * 0.75 + h * viento,
        y: cualquierAltura ? Math.random() * h : -30 - Math.random() * h * 0.4,
        l: 10 + Math.random() * 20,
        v: 9 + Math.random() * 8,
        a: 0.1 + Math.random() * 0.3
      };
    }
    function medir() {
      var r = banner.getBoundingClientRect();
      w = r.width; h = r.height;
      c.width = Math.round(w * dpr);
      c.height = Math.round(h * dpr);
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      var n = Math.min(280, Math.round((w * h) / 6500));
      gotas = [];
      for (var i = 0; i < n; i++) gotas.push(nueva(true));
    }
    function cuadro() {
      ctx.clearRect(0, 0, w, h);
      ctx.lineWidth = 1;
      ctx.lineCap = "round";
      for (var i = 0; i < gotas.length; i++) {
        var g = gotas[i];
        ctx.strokeStyle = "rgba(214, 228, 238, " + g.a + ")";
        ctx.beginPath();
        ctx.moveTo(g.x, g.y);
        ctx.lineTo(g.x - g.l * viento, g.y + g.l);
        ctx.stroke();
        g.y += g.v;
        g.x -= g.v * viento;
        if (g.y > h + 30) gotas[i] = nueva(false);
      }
      raf = requestAnimationFrame(cuadro);
    }
    function encender(si) {
      if (si && !activo && !document.hidden) { activo = true; raf = requestAnimationFrame(cuadro); }
      else if (!si && activo) { activo = false; cancelAnimationFrame(raf); }
    }
    medir();
    if ("ResizeObserver" in window) new ResizeObserver(medir).observe(banner);
    var visible = true;
    if ("IntersectionObserver" in window) {
      new IntersectionObserver(function (e) { visible = e[0].isIntersecting; encender(visible); }).observe(banner);
    }
    document.addEventListener("visibilitychange", function () { encender(visible && !document.hidden); });
    encender(true);
  }

  /* ---------- Portadas de capítulo ---------- */
  var CAPITULOS = {
    "introducción-y-pregunta": { foto: "sierras", tipo: "banda", credito: "Sierras de Carapé, Maldonado. Foto: Marcelo Campi, CC BY-SA 3.0" },
    "datos": { foto: "estacion", tipo: "dividida invertida", credito: "Estación meteorológica automática. Foto: Philip Halling, CC BY-SA 2.0" },
    "preparación-y-calidad-de-los-datos": { foto: "abrigo", tipo: "dividida gris", credito: "Parque de instrumentos meteorológicos, Fernow Experimental Forest. Dominio público" },
    "análisis": { foto: "canelon", tipo: "banda alta", credito: "Represa de Canelón Grande durante la sequía de 2022-2023. Foto: Enxuta, CC BY-SA 4.0" },
    "resultados-principales": { foto: "suelo", tipo: "dividida", credito: "Suelo agrietado por la sequía de 2022 en Aceredo, España. Foto: o_andras, CC BY-SA 4.0" },
    "conclusiones": { foto: "tormenta", tipo: "banda alta", credito: "Nubes de tormenta sobre el campo. Foto: th_norge, CC BY 4.0" }
  };

  function portadasCapitulo() {
    Object.keys(CAPITULOS).forEach(function (id) {
      var sec = document.getElementById(id);
      var h1 = sec && sec.querySelector(":scope > h1");
      if (!h1) return;
      var cfg = CAPITULOS[id];
      var cab = el("header", "capitulo " + cfg.tipo.split(" ").map(function (t) { return "capitulo--" + t; }).join(" "));
      cab.style.setProperty("--foto", "var(--foto-" + cfg.foto + ")");
      var num = h1.querySelector(".header-section-number");
      if (num) cab.setAttribute("data-num", ("0" + texto(num)).slice(-2));

      var marco = el("div", "capitulo-marco");
      var foto = el("div", "capitulo-foto");
      foto.setAttribute("role", "img");
      foto.setAttribute("aria-label", cfg.credito.split(".")[0]);
      marco.appendChild(foto);
      var cred = el("p", "capitulo-credito");
      cred.textContent = cfg.credito;

      sec.insertBefore(cab, h1);
      cab.appendChild(marco);
      cab.appendChild(h1);
      (/dividida/.test(cfg.tipo) ? marco : cab).appendChild(cred);
    });
  }

  /* ---------- Contadores del panel de cifras ---------- */
  function prepararContadores() {
    document.querySelectorAll(".cifra-valor").forEach(function (v) {
      var nodo = v.firstChild;
      if (!nodo || nodo.nodeType !== 3) return;
      var m = nodo.textContent.match(/^(\s*)([−-]?)([\d.]+)([\s\S]*)$/);
      if (!m) return;
      var miles = m[3].indexOf(".") > -1;
      var objetivo = parseInt(m[3].replace(/\./g, ""), 10);
      if (!objetivo) return;
      function formato(n) {
        var s = String(n);
        if (miles) s = s.replace(/\B(?=(\d{3})+(?!\d))/g, ".");
        return m[1] + m[2] + s + m[4];
      }
      nodo.textContent = formato(0);
      v.contar = function () {
        var t0 = null, dur = 1700;
        function paso(t) {
          if (t0 === null) t0 = t;
          var p = Math.min(1, (t - t0) / dur);
          nodo.textContent = formato(Math.round(objetivo * (1 - Math.pow(1 - p, 4))));
          if (p < 1) requestAnimationFrame(paso);
        }
        requestAnimationFrame(paso);
      };
    });
  }

  /* ---------- Comparador antes / después ---------- */
  function comparadores() {
    document.querySelectorAll(".comp-lienzo").forEach(function (l) {
      var r = l.querySelector("input[type=range]");
      if (!r) return;
      function fijar(v) { l.style.setProperty("--pos", v + "%"); }
      r.addEventListener("input", function () { l.setAttribute("data-tocado", ""); fijar(r.value); });
      r.addEventListener("pointerdown", function () { l.setAttribute("data-tocado", ""); });
      fijar(r.value);
      l.pista = function () {
        if (reduceMotion || l.hasAttribute("data-tocado")) return;
        var t0 = null, dur = 2600;
        function paso(t) {
          if (l.hasAttribute("data-tocado")) return;
          if (t0 === null) t0 = t;
          var p = Math.min(1, (t - t0) / dur);
          var v = 50 - 24 * Math.sin(p * Math.PI * 2) * (1 - p * 0.35);
          r.value = v;
          fijar(v);
          if (p < 1) requestAnimationFrame(paso);
        }
        requestAnimationFrame(paso);
      };
    });
  }

  /* ---------- Pipeline: índices y gota ---------- */
  function animarPipeline() {
    document.querySelectorAll(".pipeline-pasos").forEach(function (ol) {
      Array.prototype.forEach.call(ol.children, function (li, i) { li.style.setProperty("--p", i); });
      var gota = el("span", "pl-gota");
      gota.setAttribute("aria-hidden", "true");
      ol.appendChild(gota);
      function medir() { ol.style.setProperty("--recorrido", Math.max(0, ol.offsetHeight - 30) + "px"); }
      medir();
      if ("ResizeObserver" in window) new ResizeObserver(medir).observe(ol);
    });
    document.querySelectorAll(".barras li").forEach(function (li, i) { li.style.setProperty("--b", i % 6); });
  }

  function botonVolver() {
    var banner = document.querySelector("#title-block-header");
    if (!banner || !("IntersectionObserver" in window)) return;
    var b = el("button", "volver", "↑ Inicio");
    b.type = "button";
    b.setAttribute("aria-label", "Volver al inicio");
    b.addEventListener("click", function () { window.scrollTo({ top: 0, behavior: reduceMotion ? "auto" : "smooth" }); });
    document.body.appendChild(b);
    new IntersectionObserver(function (e) { b.classList.toggle("visible", !e[0].isIntersecting); }).observe(banner);

    var t = el("button", "volver interruptor", movimiento ? "Animaciones: sí" : "Animaciones: no");
    t.type = "button";
    t.setAttribute("aria-pressed", movimiento ? "true" : "false");
    t.addEventListener("click", function () {
      try { localStorage.setItem(CLAVE, movimiento ? "no" : "si"); } catch (e) {}
      location.reload();
    });
    document.body.appendChild(t);
    new IntersectionObserver(function (e) { t.classList.toggle("visible", !e[0].isIntersecting); }).observe(banner);
  }

  /* ---------- Rótulos de figuras y tablas ---------- */
  function rotularLeyendas() {
    document.querySelectorAll("figcaption.quarto-float-caption").forEach(function (cap) {
      var html = cap.innerHTML;
      var m = html.match(/^\s*((?:Figura|Tabla|Figure|Table)(?:\s|&nbsp;| )+[\d.]+)\s*:\s*/);
      if (!m) return;
      cap.innerHTML =
        '<span class="cap-num">' + m[1].replace(/&nbsp;| /g, " ") + "</span>" +
        '<span class="cap-texto">' + html.slice(m[0].length).trim() + "</span>";
    });
  }

  /* ---------- Listas con rótulo en negrita ---------- */
  function listasRotuladas() {
    var selectores = ["#decisiones-de-preparación > ol", "#validaciones-del-pipeline > ul", "#limitaciones > ul"];
    selectores.forEach(function (sel) {
      var lista = document.querySelector(sel);
      if (!lista) return;
      var items = Array.prototype.slice.call(lista.children);
      var ok = items.length && items.every(function (li) {
        return li.firstElementChild && li.firstElementChild.tagName === "STRONG" && li.firstChild === li.firstElementChild;
      });
      if (!ok) return;
      lista.classList.add("lista-rotulada");
      items.forEach(function (li) {
        var rotulo = el("span", "rotulo");
        rotulo.appendChild(li.firstElementChild);
        var cuerpo = el("span", "cuerpo");
        while (li.firstChild) cuerpo.appendChild(li.firstChild);
        var s = rotulo.querySelector("strong");
        s.textContent = s.textContent.replace(/[.:]\s*$/, "");
        cuerpo.innerHTML = cuerpo.innerHTML.replace(/^\s*[:.]?\s*/, "");
        li.appendChild(rotulo);
        li.appendChild(cuerpo);
      });
    });
  }

  /* ---------- Tablas ---------- */
  function columnas(tabla) {
    return Array.prototype.map.call(tabla.querySelectorAll("thead th"), texto);
  }

  function barrasDivergentes(tabla, idx) {
    var celdas = Array.prototype.map.call(tabla.querySelectorAll("tbody tr"), function (tr) { return tr.children[idx]; });
    var vals = celdas.map(function (td) { return td ? numero(texto(td)) : NaN; });
    var max = Math.max.apply(null, vals.filter(isFinite).map(Math.abs));
    if (!isFinite(max) || max === 0) return;
    var hayNeg = vals.some(function (v) { return v < 0; });
    var hayPos = vals.some(function (v) { return v > 0; });
    var cero = hayNeg && hayPos ? 50 : hayNeg ? 100 : 0;
    var escala = hayNeg && hayPos ? 50 : 100;

    celdas.forEach(function (td, i) {
      var v = vals[i];
      if (!td || !isFinite(v)) return;
      var largo = (Math.abs(v) / max) * escala;
      var izq = v < 0 ? cero - largo : cero;
      var wrap = el("div", "celda-barra");
      var pista = el("span", "cb-pista");
      pista.style.setProperty("--cero", cero + "%");
      var barra = el("span", "cb-barra" + (v < 0 ? " neg" : ""));
      barra.style.left = izq + "%";
      barra.style.width = largo + "%";
      barra.style.transformOrigin = v < 0 ? "right center" : "left center";
      pista.appendChild(barra);
      var valor = el("span", "cb-valor", td.innerHTML);
      wrap.appendChild(pista);
      wrap.appendChild(valor);
      td.innerHTML = "";
      td.appendChild(wrap);
    });
  }

  function graficoIntervalos(tabla, idxPend, idxIC) {
    var filas = Array.prototype.slice.call(tabla.querySelectorAll("tbody tr"));
    var datos = filas.map(function (tr) {
      var p = numero(texto(tr.children[idxPend]));
      var ic = texto(tr.children[idxIC]).split(/\s+a\s+/).map(numero);
      return { p: p, lo: ic[0], hi: ic[1] };
    });
    if (datos.some(function (d) { return !isFinite(d.p) || !isFinite(d.lo) || !isFinite(d.hi); })) return;

    var min = Math.min(0, Math.min.apply(null, datos.map(function (d) { return d.lo; })));
    var max = Math.max(0, Math.max.apply(null, datos.map(function (d) { return d.hi; })));
    var paso = 50;
    min = Math.floor(min / paso) * paso;
    max = Math.ceil(max / paso) * paso;
    var W = 180, pad = 6;
    function x(v) { return pad + ((v - min) / (max - min)) * (W - 2 * pad); }

    var th = el("th", "col-ic");
    function rotulo(v) {
      var t = v === 0 ? "0" : v < 0 ? "−" + Math.abs(v) : "+" + v;
      return '<span style="left:' + x(v) + 'px">' + t + "</span>";
    }
    th.innerHTML = "Pendiente e IC 95 %" + '<span class="ic-eje">' + rotulo(min) + rotulo(0) + rotulo(max) + "</span>";
    var thIC = tabla.querySelectorAll("thead th")[idxIC];
    thIC.parentNode.insertBefore(th, thIC.nextSibling);

    filas.forEach(function (tr, i) {
      var d = datos[i];
      var svg = document.createElementNS(NS, "svg");
      svg.setAttribute("class", "ic-svg");
      svg.setAttribute("viewBox", "0 0 " + W + " 22");
      svg.setAttribute("role", "img");
      svg.setAttribute("aria-label", "Pendiente " + texto(tr.children[idxPend]) + " mm/año, IC 95 % " + texto(tr.children[idxIC]));
      function linea(cls, x1, y1, x2, y2) {
        var l = document.createElementNS(NS, "line");
        l.setAttribute("class", cls);
        l.setAttribute("x1", x1); l.setAttribute("y1", y1);
        l.setAttribute("x2", x2); l.setAttribute("y2", y2);
        svg.appendChild(l);
      }
      linea("ic-cero", x(0), 1, x(0), 21);
      linea("ic-linea", x(d.lo), 11, x(d.hi), 11);
      linea("ic-linea", x(d.lo), 7, x(d.lo), 15);
      linea("ic-linea", x(d.hi), 7, x(d.hi), 15);
      var c = document.createElementNS(NS, "circle");
      c.setAttribute("class", "ic-punto " + (d.p < 0 ? "neg" : "pos"));
      c.setAttribute("cx", x(d.p)); c.setAttribute("cy", 11); c.setAttribute("r", 4.2);
      svg.appendChild(c);
      var td = el("td", "col-ic");
      td.appendChild(svg);
      tr.insertBefore(td, tr.children[idxIC].nextSibling);
    });
  }

  function mejorarTablas() {
    document.querySelectorAll("main.content table.table").forEach(function (tabla) {
      var cab = columnas(tabla);
      var flotante = tabla.closest(".quarto-float");
      var leyenda = flotante ? texto(flotante.querySelector("figcaption") || flotante) : "";
      var esCalidad = /calidad/i.test(leyenda) && cab.some(function (c) { return /ausentes|duplicadas/i.test(c); });

      tabla.querySelectorAll("tbody tr").forEach(function (tr, i) { tr.style.setProperty("--f", i); });

      tabla.querySelectorAll("tbody td").forEach(function (td) {
        var t = texto(td);
        if (isFinite(numero(t))) {
          td.classList.add("num");
          if (/^−|^-/.test(t)) td.classList.add("neg");
        }
      });

      if (esCalidad) {
        tabla.querySelectorAll("tbody tr").forEach(function (tr) {
          Array.prototype.forEach.call(tr.children, function (td, j) {
            if (j < 2) return;
            var v = numero(texto(td));
            if (v === 0) td.classList.add("es-cero");
            else if (v > 0) { td.classList.add("es-alerta"); td.innerHTML = "<span>" + td.innerHTML + "</span>"; }
          });
        });
      }

      cab.forEach(function (c, i) {
        if (/^(balance 20|anomal[ií]a 20|peor acumulado)/i.test(c)) barrasDivergentes(tabla, i);
      });

      var iPend = cab.findIndex(function (c) { return /^pendiente/i.test(c); });
      var iIC = cab.findIndex(function (c) { return /^IC\s*95/i.test(c); });
      if (iPend > -1 && iIC > -1) graficoIntervalos(tabla, iPend, iIC);
    });
  }

  /* ---------- Panel de cifras: barras a partir de data-valor ---------- */
  function barrasCifras() {
    document.querySelectorAll(".barras").forEach(function (lista) {
      var items = Array.prototype.slice.call(lista.querySelectorAll("li[data-valor]"));
      var vals = items.map(function (li) { return parseFloat(li.getAttribute("data-valor")); });
      var max = Math.max.apply(null, vals.map(Math.abs));
      items.forEach(function (li, i) {
        var v = vals[i];
        var barra = li.querySelector(".b-barra");
        if (!barra || !isFinite(v) || !max) return;
        var largo = (Math.abs(v) / max) * 50;
        barra.style.width = largo + "%";
        barra.style.left = (v < 0 ? 50 - largo : 50) + "%";
        barra.style.setProperty("--origen", v < 0 ? "right" : "left");
        if (v < 0) barra.classList.add("neg");
      });
    });
  }

  /* ---------- Visor de figuras ---------- */
  function visorFiguras() {
    var figs = document.querySelectorAll("main.content figure.quarto-float-fig");
    if (!figs.length || typeof HTMLDialogElement === "undefined") return;

    var dlg = el("dialog", "visor");
    dlg.setAttribute("aria-label", "Figura ampliada");
    dlg.innerHTML = '<div class="visor-cab"><span class="visor-titulo"></span><button type="button">Cerrar  Esc</button></div><img alt="">';
    document.body.appendChild(dlg);
    var titulo = dlg.querySelector(".visor-titulo");
    var img = dlg.querySelector("img");
    dlg.querySelector("button").addEventListener("click", function () { dlg.close(); });
    dlg.addEventListener("click", function (e) { if (e.target === dlg || e.target === img) dlg.close(); });

    figs.forEach(function (fig) {
      var im = fig.querySelector("img.figure-img");
      if (!im) return;
      var cap = fig.querySelector("figcaption");
      var num = cap && cap.querySelector(".cap-num");
      var cuerpo = cap && cap.querySelector(".cap-texto");
      var nombre = num && cuerpo ? texto(num) + ": " + texto(cuerpo) : cap ? texto(cap) : "Figura";
      if (!im.getAttribute("alt")) im.setAttribute("alt", nombre);
      function abrir() {
        img.src = im.src;
        img.alt = im.alt;
        titulo.textContent = nombre;
        dlg.showModal();
      }
      var btn = el("button", "ampliar", "Ampliar");
      btn.type = "button";
      btn.setAttribute("aria-label", "Ampliar " + nombre);
      btn.addEventListener("click", abrir);
      im.addEventListener("click", abrir);
      fig.appendChild(btn);
    });
  }

  /* ---------- Aparición al hacer scroll ---------- */
  function revelar() {
    if (reduceMotion || !("IntersectionObserver" in window)) return;
    var objetivos = document.querySelectorAll(
      "main.content .cifras, main.content .pipeline, main.content .quarto-float, main.content .callout, " +
      "#resultados-principales > ol > li, main.content .mapa, main.content .comparador, main.content .capitulo, main.content h1:not(.title)"
    );
    if (!objetivos.length) return;
    document.documentElement.classList.add("revelar-js");
    prepararContadores();
    var io = new IntersectionObserver(function (entradas) {
      entradas.forEach(function (e) {
        if (!e.isIntersecting) return;
        var o = e.target;
        o.classList.add("visible");
        io.unobserve(o);
        o.querySelectorAll(".cifra-valor").forEach(function (v) { if (v.contar) v.contar(); });
        o.querySelectorAll(".comp-lienzo").forEach(function (l) { if (l.pista) setTimeout(l.pista, 700); });
      });
    }, { rootMargin: "0px 0px -8% 0px", threshold: 0.08 });
    objetivos.forEach(function (o, i) {
      if (o.matches("h1") && o.closest(".capitulo")) return;
      o.classList.add("revelar");
      if (o.matches("#resultados-principales li")) o.style.transitionDelay = (i % 5) * 60 + "ms";
      io.observe(o);
    });
  }

  function progreso() {
    var barra = el("div", "lectura-progreso");
    barra.setAttribute("aria-hidden", "true");
    document.body.appendChild(barra);
  }

  function iniciar() {
    armarPortada();
    portadasCapitulo();
    rotularLeyendas();
    listasRotuladas();
    mejorarTablas();
    barrasCifras();
    animarPipeline();
    comparadores();
    visorFiguras();
    progreso();
    botonVolver();
    revelar();
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", iniciar);
  else iniciar();
})();
