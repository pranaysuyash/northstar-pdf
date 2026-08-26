import React from "react";

interface PageThumbnailRailProps {
  pageCount: number;
  currentPageIndex: number;
  onSelectPage: (index: number) => void;
  fieldCountsByPage?: Record<number, number>;
}

export const PageThumbnailRail: React.FC<PageThumbnailRailProps> = ({
  pageCount,
  currentPageIndex,
  onSelectPage,
  fieldCountsByPage = {}
}) => {
  return (
    <nav aria-label="Page Thumbnails" className="w-52 border-r border-slate-800 bg-slate-950/80 backdrop-blur flex flex-col h-full overflow-y-auto p-3 space-y-3">
      <div className="text-[10px] uppercase font-bold text-slate-500 tracking-wider px-1">
        Pages ({pageCount})
      </div>

      <div className="space-y-3">
        {Array.from({ length: pageCount }).map((_, idx) => {
          const isSelected = idx === currentPageIndex;
          const fieldCount = fieldCountsByPage[idx] || 0;

          return (
            <div
              key={idx}
              className={`p-2.5 rounded-lg cursor-pointer border transition-all ${
                isSelected
                  ? "bg-slate-900 border-cyan-500 shadow-md ring-1 ring-cyan-500/50"
                  : "bg-slate-900/40 border-slate-800 hover:border-slate-700 hover:bg-slate-900/80"
              }`}
              onClick={() => onSelectPage(idx)}
            >
              <div className="aspect-[3/4] bg-slate-950 rounded border border-slate-800 flex items-center justify-center relative overflow-hidden mb-2">
                <span className="text-slate-600 font-mono text-xs">Page {idx + 1}</span>
                {fieldCount > 0 && (
                  <span className="absolute top-1 right-1 px-1.5 py-0.5 bg-cyan-950/90 border border-cyan-700 text-cyan-300 rounded text-[9px] font-bold">
                    {fieldCount} {fieldCount === 1 ? "field" : "fields"}
                  </span>
                )}
              </div>

              <div className="flex items-center justify-between text-[11px] text-slate-400">
                <span className="font-medium">Page {idx + 1}</span>
                <span className="text-[10px] text-slate-500">612 × 792 pt</span>
              </div>
            </div>
          );
        })}
      </div>
    </nav>
  );
};
