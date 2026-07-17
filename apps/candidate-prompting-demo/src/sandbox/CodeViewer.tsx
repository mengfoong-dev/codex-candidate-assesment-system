import { javascript } from '@codemirror/lang-javascript';
import CodeMirror from '@uiw/react-codemirror';

type Props = {
  content: string;
  path?: string;
};

/**
 * Read-only, syntax-highlighted view of the selected file. Edits are AI-only (the copilot's
 * write_file over SSE), so this is a viewer — `editable={false}` — not an editor.
 */
export function CodeViewer({ content, path }: Props) {
  return (
    <div className="pane sandbox-editor" aria-label="Code viewer">
      <p className="panel-kicker panel-kicker-violet">{path || 'Code'}</p>
      <CodeMirror
        value={content}
        editable={false}
        height="360px"
        extensions={[javascript({ typescript: true })]}
      />
    </div>
  );
}
