declare module 'html2pdf.js' {
  type Html2PdfOptions = {
    margin?: number;
    filename?: string;
    image?: {
      type?: string;
      quality?: number;
    };
    html2canvas?: {
      scale?: number;
      useCORS?: boolean;
    };
    jsPDF?: {
      unit?: string;
      format?: string;
      orientation?: string;
    };
  };

  type Html2PdfInstance = {
    set: (options: Html2PdfOptions) => Html2PdfInstance;
    from: (source: HTMLElement) => Html2PdfInstance;
    save: () => Promise<void>;
  };

  export default function html2pdf(): Html2PdfInstance;
}
