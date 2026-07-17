import type { SessionFileRef } from '../api';

type Props = {
  files: SessionFileRef[];
  selected: string;
  onSelect: (path: string) => void;
};

/** Left pane: the session's workspace files. Selecting one drives the CodeViewer. */
export function FileList({ files, selected, onSelect }: Props) {
  return (
    <div className="pane sandbox-files" aria-label="Workspace files">
      <p className="panel-kicker panel-kicker-cyan">Workspace files</p>
      <ul className="file-list">
        {files.map((file) => (
          <li key={file.path}>
            <button
              type="button"
              className={file.path === selected ? 'file-item active' : 'file-item'}
              onClick={() => onSelect(file.path)}
            >
              <span className="file-path">{file.path}</span>
              <span className="file-source">{file.source}</span>
            </button>
          </li>
        ))}
      </ul>
    </div>
  );
}
