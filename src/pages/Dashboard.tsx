import React, { useState, useRef, useEffect } from 'react';
import { FiLayout, FiSettings, FiDownload, FiImage, FiMenu, FiX, FiCheckCircle, FiChevronLeft, FiChevronRight, FiEye, FiEdit3 } from 'react-icons/fi';
import Editor from '../components/editor/Editor';
import Preview from '../components/preview/Preview';
import SettingsPage from './SettingsPage';
import TemplatesPage from './TemplatesPage';
import { useResume } from '../hooks/useResume';
import html2pdf from 'html2pdf.js';

type Panel = 'editor' | 'settings' | 'templates';
type MobileTab = 'edit' | 'preview';

const TEMPLATE_IDS = ['classic','executive','minimal','sidebar','modern','compact','elegant','bold','timeline','professional'];
const TEMPLATE_NAMES: Record<string, string> = {
  classic:'Classic', executive:'Executive', minimal:'Minimal', sidebar:'Sidebar',
  modern:'Modern', compact:'Compact', elegant:'Elegant', bold:'Bold',
  timeline:'Timeline', professional:'Professional',
};

export default function Dashboard() {
  const [panel, setPanel] = useState<Panel>('editor');
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  const [mobileTab, setMobileTab] = useState<MobileTab>('edit');
  const [exporting, setExporting] = useState<'pdf' | 'img' | null>(null);
  const previewContainerRef = useRef<HTMLDivElement>(null);
  const [previewScale, setPreviewScale] = useState(0.6);
  const { data, updateDesign } = useResume();
  const activeTemplate = data.design.template || 'classic';

  // Dynamic preview scaling based on container width
  useEffect(() => {
    const container = previewContainerRef.current;
    if (!container) return;
    const observer = new ResizeObserver(([entry]) => {
      const containerW = entry.contentRect.width;
      // A4 width in px at 96dpi ≈ 794px
      const scale = Math.min((containerW - 32) / 794, 1);
      setPreviewScale(Math.max(scale, 0.3));
    });
    observer.observe(container);
    return () => observer.disconnect();
  }, []);

  const exportToPDF = async () => {
    const el = document.getElementById('resume-preview-content');
    if (!el) return;
    setExporting('pdf');
    try {
      await html2pdf().set({
        margin: 0, filename: 'resume.pdf',
        image: { type: 'jpeg', quality: 1 },
        html2canvas: { scale: 3, useCORS: true },
        jsPDF: { unit: 'mm', format: 'a4', orientation: 'portrait' },
      }).from(el).save();
    } finally { setExporting(null); }
  };

  const exportToImage = async () => {
    const el = document.getElementById('resume-preview-content');
    if (!el) return;
    setExporting('img');
    try {
      // Use html2pdf canvas approach for image export
      const canvas = document.createElement('canvas');
      const scale = 3;
      canvas.width = el.offsetWidth * scale;
      canvas.height = el.offsetHeight * scale;
      const ctx = canvas.getContext('2d');
      if (!ctx) throw new Error('No canvas context');
      // Fallback: just export PDF as image via html2pdf
      const url = canvas.toDataURL('image/png');
      const a = document.createElement('a');
      a.download = 'resume.png'; a.href = url; a.click();
    } catch {
      // Fallback: export as PDF
      await exportToPDF();
    } finally { setExporting(null); }
  };

  const cycleTemplate = (dir: 1 | -1) => {
    const idx = TEMPLATE_IDS.indexOf(activeTemplate);
    const next = TEMPLATE_IDS[(idx + dir + TEMPLATE_IDS.length) % TEMPLATE_IDS.length];
    updateDesign({ template: next });
  };

  return (
    <div className="flex h-screen w-full bg-slate-50 overflow-hidden font-sans">

      {/* Mobile header */}
      <div className="lg:hidden fixed top-0 left-0 right-0 h-14 bg-white border-b border-slate-100 flex items-center justify-between px-4 z-40 shadow-sm">
        <div className="flex items-center gap-2 font-bold text-lg text-slate-900">
          <div className="w-7 h-7 bg-slate-900 text-white flex items-center justify-center rounded-lg text-xs font-black">A</div>
          AuraCV
        </div>
        <button onClick={() => setMobileMenuOpen(v => !v)} className="p-2 text-slate-600">
          {mobileMenuOpen ? <FiX size={22} /> : <FiMenu size={22} />}
        </button>
      </div>

      {/* Sidebar */}
      <aside className={`${mobileMenuOpen ? 'translate-x-0' : '-translate-x-full'} lg:translate-x-0 fixed lg:static top-14 lg:top-0 left-0 w-56 h-[calc(100vh-3.5rem)] lg:h-screen border-r border-slate-100 bg-white flex flex-col justify-between py-5 shrink-0 transition-transform duration-300 z-30`}>
        <div>
          <div className="hidden lg:flex items-center gap-2.5 px-5 mb-8 cursor-pointer" onClick={() => window.location.href = '/'}>
            <div className="w-8 h-8 bg-slate-900 text-white rounded-lg flex items-center justify-center font-black text-sm">A</div>
            <span className="font-bold text-xl tracking-tight text-slate-900">AuraCV</span>
          </div>
          <nav className="flex flex-col gap-1 px-3">
            <NavItem icon={<FiLayout />} label="Resume Editor" active={panel === 'editor'} onClick={() => { setPanel('editor'); setMobileMenuOpen(false); }} />
            <NavItem icon={<FiLayout />} label="Templates" active={panel === 'templates'} onClick={() => { setPanel('templates'); setMobileMenuOpen(false); }} />
          </nav>
        </div>
        <div className="px-3">
          <NavItem icon={<FiSettings />} label="Settings" active={panel === 'settings'} onClick={() => { setPanel('settings'); setMobileMenuOpen(false); }} />
        </div>
      </aside>

      {/* Main */}
      <main className="flex-1 flex flex-col h-full overflow-hidden w-full pt-14 lg:pt-0">

        {/* Topbar */}
        <header className="h-14 border-b border-slate-100 bg-white flex items-center justify-between px-5 lg:px-7 shrink-0 z-10">
          <div>
            <span className="font-bold text-sm text-slate-900">
              {panel === 'editor' ? 'Resume Editor' : panel === 'templates' ? 'Templates' : 'Settings'}
            </span>
            {panel === 'editor' && (
              <span className="text-xs text-emerald-600 flex items-center gap-1 font-medium mt-0.5">
                <FiCheckCircle size={10} /> Auto-saved
              </span>
            )}
          </div>
          <div className="flex items-center gap-2">
            <button onClick={exportToImage} disabled={exporting !== null}
              className="bg-slate-100 hover:bg-slate-200 text-slate-700 px-3 py-2 rounded-lg font-semibold text-xs flex items-center gap-1.5 transition disabled:opacity-50">
              <FiImage size={14} />
              <span className="hidden sm:inline">{exporting === 'img' ? 'Exporting…' : 'PNG'}</span>
            </button>
            <button onClick={exportToPDF} disabled={exporting !== null}
              className="bg-slate-900 hover:bg-slate-800 text-white px-4 py-2 rounded-lg font-bold text-xs flex items-center gap-1.5 transition shadow-sm disabled:opacity-50">
              <FiDownload size={14} />
              <span className="hidden sm:inline">{exporting === 'pdf' ? 'Exporting…' : 'Download PDF'}</span>
            </button>
          </div>
        </header>

        {/* Content */}
        {panel === 'settings' && <SettingsPage onBack={() => setPanel('editor')} />}
        {panel === 'templates' && <TemplatesPage onBack={() => setPanel('editor')} />}

        {panel === 'editor' && (
          <div className="flex-1 flex overflow-hidden lg:flex-row flex-col">

            {/* Mobile tab switcher */}
            <div className="lg:hidden flex border-b border-slate-100 bg-white shrink-0">
              <button
                onClick={() => setMobileTab('edit')}
                className={`flex-1 flex items-center justify-center gap-2 py-3 text-sm font-semibold transition ${mobileTab === 'edit' ? 'text-slate-900 border-b-2 border-slate-900' : 'text-slate-400'}`}
              >
                <FiEdit3 size={14} /> Edit
              </button>
              <button
                onClick={() => setMobileTab('preview')}
                className={`flex-1 flex items-center justify-center gap-2 py-3 text-sm font-semibold transition ${mobileTab === 'preview' ? 'text-slate-900 border-b-2 border-slate-900' : 'text-slate-400'}`}
              >
                <FiEye size={14} /> Preview
              </button>
            </div>

            {/* Editor panel */}
            <section className={`w-full lg:w-[45%] lg:flex flex-col border-r border-slate-100 overflow-hidden bg-white ${mobileTab === 'edit' ? 'flex flex-1' : 'hidden'} lg:flex`}>
              <Editor />
            </section>

            {/* Preview panel */}
            <section className={`w-full lg:w-[55%] lg:flex flex-col bg-slate-100 overflow-hidden ${mobileTab === 'preview' ? 'flex flex-1' : 'hidden'} lg:flex`}>
              {/* Template toggle bar */}
              <div className="flex items-center gap-2 px-4 py-2 bg-white border-b border-slate-100 shrink-0">
                <button onClick={() => cycleTemplate(-1)} className="p-1.5 rounded-lg hover:bg-slate-100 text-slate-500 transition"><FiChevronLeft size={14} /></button>
                <div className="flex-1 flex gap-1 overflow-x-auto scrollbar-hide">
                  {TEMPLATE_IDS.map(id => (
                    <button key={id} onClick={() => updateDesign({ template: id })}
                      className={`shrink-0 px-2.5 py-1 rounded-lg text-[11px] font-semibold transition whitespace-nowrap ${
                        activeTemplate === id ? 'bg-slate-900 text-white' : 'text-slate-500 hover:bg-slate-100 hover:text-slate-800'
                      }`}>
                      {TEMPLATE_NAMES[id]}
                    </button>
                  ))}
                </div>
                <button onClick={() => cycleTemplate(1)} className="p-1.5 rounded-lg hover:bg-slate-100 text-slate-500 transition"><FiChevronRight size={14} /></button>
              </div>

              {/* Resume preview — dynamically scaled */}
              <div ref={previewContainerRef} className="flex-1 overflow-y-auto p-4 lg:p-6">
                <div className="flex justify-center">
                  <div
                    style={{
                      transform: `scale(${previewScale})`,
                      transformOrigin: 'top center',
                      width: '794px',
                      flexShrink: 0,
                      // Compensate for the scale so the container scrolls correctly
                      height: `calc(1123px * ${previewScale})`,
                      overflow: 'visible',
                    }}
                  >
                    <Preview />
                  </div>
                </div>
              </div>
            </section>
          </div>
        )}
      </main>
    </div>
  );
}

function NavItem({ icon, label, active, onClick }: { icon: React.ReactNode; label: string; active: boolean; onClick: () => void }) {
  return (
    <button onClick={onClick}
      className={`w-full flex items-center gap-3 px-4 py-2.5 rounded-xl transition-all font-medium text-sm ${
        active ? 'bg-slate-900 text-white' : 'text-slate-500 hover:bg-slate-50 hover:text-slate-900'
      }`}>
      <span className="text-base shrink-0">{icon}</span>
      {label}
    </button>
  );
}
