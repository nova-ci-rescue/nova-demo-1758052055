#!/usr/bin/env bash
# Nova CI-Rescue — GitHub Quickstart Demo
# The fastest way to see Nova fix failing tests in GitHub Actions

set -Eeuo pipefail

# Use existing GitHub CLI authentication
# Don't override authenticated session

########################################
# Args & Defaults
########################################
VERBOSE=false
FORCE_YES=false
NO_BROWSER=true
REPO_NAME=""
ORG_OR_USER=""
PUBLIC=true
DEMO_KIND="topk"  # topk | retrieval (default: topk)
NUM_BUGS=1  # Number of bugs to inject (default: 1)

OPEN_PR=false
for arg in "$@"; do
    case $arg in
        -y|--yes) FORCE_YES=true; shift ;;
        -v|--verbose) VERBOSE=true; shift ;;
        --no-browser) NO_BROWSER=true; shift ;;
        --open-pr) OPEN_PR=true; shift ;;
        --no-open) OPEN_PR=false; shift ;;
        --public) PUBLIC=true; shift ;;
        --demo=*) DEMO_KIND="${arg#*=}"; shift ;;
        --repo=*) REPO_NAME="${arg#*=}"; shift ;;
        --org=*) ORG_OR_USER="${arg#*=}"; shift ;;
        --bugs=*) NUM_BUGS="${arg#*=}"; shift ;;
        -h|--help)
            echo "Nova CI-Rescue GitHub Quickstart"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Creates a GitHub repo with failing tests and shows Nova fixing them automatically."
            echo ""
            echo "Options:"
            echo "  --repo=<name>        Name for the demo repo (default: nova-quickstart-<ts>)"
            echo "  --org=<org|user>     Owner (GitHub org or user). Default: joinnova-ci"
            echo "  --demo=<topk|retrieval>  Which demo to generate (default: topk)"
            echo "  --bugs=<number>      Number of bugs to inject (default: 1, range: 1-6)"
            echo "  --public             Create as public repo (default: private)"
            echo "  --open-pr            Open created PR in browser automatically"
            echo "  --no-open            Do not open PR in browser (default)"
            echo "  -y, --yes            Non-interactive mode"
            echo "  -v, --verbose        Show detailed output"
            echo "  --no-browser         Do not open browser automatically"
            echo "  -h, --help           Show help"
            echo ""
            echo "Examples:"
            echo "  $0 --public --repo=my-nova-demo  # Retrieval is default (1 bug)"
            echo "  $0 --bugs=3 --repo=multi-bug-demo  # Multiple bugs for testing"
            exit 0
            ;;
    esac
done

########################################
# Terminal Intelligence & Visuals
########################################
detect_terminal() {
    TERM_WIDTH=$(tput cols 2>/dev/null || echo 80)
    TERM_HEIGHT=$(tput lines 2>/dev/null || echo 24)
    CAN_UTF8=false
    if echo -e '\u2713' | grep -q '✓' 2>/dev/null; then CAN_UTF8=true; fi
}

setup_visuals() {
    BOLD=$'\033[1m'; DIM=$'\033[2m'; UNDERLINE=$'\033[4m'; NC=$'\033[0m'
    RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; BLUE=$'\033[0;34m'; CYAN=$'\033[0;36m'; PURPLE=$'\033[0;35m'
    if [ "$CAN_UTF8" = true ]; then CHECK="✓"; CROSS="✗"; SPARKLE="✨"; ROCKET="🚀"; PACKAGE="📦"; BRAIN="🧠"; PR="🔀"; KEY="🔑"; else CHECK="[OK]"; CROSS="[X]"; SPARKLE="*"; ROCKET=">"; PACKAGE="[]"; BRAIN="AI"; PR="PR"; KEY="KEY"; fi
}

hr() { printf '%*s\n' "${TERM_WIDTH}" '' | tr ' ' '─'; }
thr() { printf '%*s\n' "${TERM_WIDTH}" '' | tr ' ' '━'; }

banner() {
    clear || true
    echo
    echo
    thr
    echo "Nova CI-Rescue — GitHub Quickstart"
    echo "See Nova fix failing tests in GitHub Actions"
    thr
    echo
}

step() {
    local n="$1"; local t="$2"; local msg="$3"; local icon="${4:-$PACKAGE}"
    echo
    echo "Step ${n}/${t} – ${icon} ${msg}"
    hr
}

ok() { echo -e "${GREEN}✓${NC} $1"; }
err() { echo -e "${RED}✗${NC} $1"; }
info() { echo -e "${CYAN}ℹ${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }

# Cross-platform URL opener (prefers gh browse)
open_url() {
  local url="$1"
  case "$OSTYPE" in
    darwin*) command -v open >/dev/null 2>&1 && open "$url" >/dev/null 2>&1 && return 0 ;;
    linux*)  command -v xdg-open >/dev/null 2>&1 && xdg-open "$url" >/dev/null 2>&1 && return 0 ;;
    msys*|cygwin*) command -v start >/dev/null 2>&1 && start "" "$url" >/dev/null 2>&1 && return 0 ;;
  esac
  # last resort: try GitHub CLI to open current PR page
  if command -v gh >/dev/null 2>&1; then
    gh pr view --web >/dev/null 2>&1 || true
    return 0
  fi
  return 0
}

ask_yes() {
    local prompt="$1"; local default="${2:-Y}"; local yn="[Y/n]"; [ "$default" = "N" ] && yn="[y/N]"
    if [ "$FORCE_YES" = true ]; then return 0; fi
    printf "%s %s " "$prompt" "$yn"; read -r REPLY; REPLY="${REPLY:-$default}"; [[ "$REPLY" =~ ^[Yy]$ ]]
}

########################################
# Preflight
########################################
need() { command -v "$1" >/dev/null 2>&1 || { err "Missing dependency: $1"; exit 1; }; }

seed_retrieval_demo() {
    # Seed a retrieval-style project with tests (always generate extended module)
    mkdir -p src tests
    : > src/__init__.py
    : > tests/__init__.py
    python - <<'PY'
from pathlib import Path
import textwrap

def build_content() -> str:
    lines: list[str] = []
    add = lines.append

    add('"""Retrieval Pipeline (extended demo)\n\nThis module intentionally contains a rich set of retrieval- and RAG-related utilities\nso the quickstart can demonstrate Nova fixing multiple classes of issues.\n\nSections:\n  - Vector math and similarity\n  - Ranking and top-k selection\n  - Chunking and adaptive chunking\n  - Quality metrics and thresholding\n  - Clustering and reranking\n  - Query expansion\n  - Drift detection\n\nNote: Some simple implementations are used for demonstration purposes.\n"""')
    add('import numpy as np')
    add('from typing import List, Tuple, Sequence, Dict')
    add('from dataclasses import dataclass')
    add('from collections import Counter, defaultdict')
    add('import math')
    add('')

    add('def cosine_sim(a: np.ndarray, b: np.ndarray) -> float:')
    add('    """Cosine similarity with proper L2 normalization on both vectors."""')
    add('    a_norm = a / (np.linalg.norm(a) or 1.0)')
    add('    b_norm = b / (np.linalg.norm(b) or 1.0)  # BUG_HOOK_NORM')
    add('    return float(np.dot(a_norm, b_norm))')
    add('')

    add('def rank(documents: List[str], query_embedding: np.ndarray, doc_embeddings: List[np.ndarray], top_k: int = 5) -> List[int]:')
    add('    sims: List[Tuple[float, int]] = [(cosine_sim(query_embedding, e), i) for i, e in enumerate(doc_embeddings)]')
    add('    sims.sort(key=lambda x: x[0], reverse=True)  # BUG_HOOK_SORT')
    add('    return [i for _, i in sims[:top_k]]  # BUG_HOOK_SLICE')
    add('')

    add('def chunk_document(text: str, window: int = 100, overlap: int = 20) -> List[str]:')
    add('    """Simple fixed-window chunking with overlap."""')
    add('    if window <= 0:')
    add('        return []')
    add('    chunks: List[str] = []')
    add('    start = 0')
    add('    n = len(text)')
    add('    while start < n:')
    add('        end = min(n, start + window)')
    add('        chunks.append(text[start:end])')
    add('        start = end - overlap  # BUG_HOOK_OVERLAP')
    add('        if start <= 0:')
    add('            start = end')
    add('    return chunks')
    add('')

    add('def compute_embedding_quality(vectors: Sequence[np.ndarray]) -> Dict[str, float]:')
    add('    if not vectors:')
    add('        return {"mean": 0.0, "variance": 0.0}')
    add('    vs = np.array([float(np.linalg.norm(v)) for v in vectors], dtype=float)')
    add('    return {"mean": float(np.mean(vs)), "variance": float(np.var(vs))}  # BUG_HOOK_VARIANCE')
    add('')

    add('def optimize_retrieval_threshold(y_true: Sequence[int], scores: Sequence[float]) -> Tuple[float, float]:')
    add('    """Return (best_threshold, best_f1)."""')
    add('    if not scores:')
    add('        return 0.0, 0.0')
    add('    thresholds = np.linspace(0.0, 1.0, 51)')
    add('    best_f1 = -1.0')
    add('    best_t = 0.0')
    add('    y_true_np = np.array(y_true, dtype=int)')
    add('    scores_np = np.array(scores, dtype=float)')
    add('    for t in thresholds:')
    add('        y_pred = (scores_np >= t).astype(int)')
    add('        tp = int(np.sum((y_pred == 1) & (y_true_np == 1)))')
    add('        fp = int(np.sum((y_pred == 1) & (y_true_np == 0)))')
    add('        fn = int(np.sum((y_pred == 0) & (y_true_np == 1)))')
    add('        precision = tp / (tp + fp) if (tp + fp) > 0 else 0.0')
    add('        recall = tp / (tp + fn) if (tp + fn) > 0 else 0.0')
    add('        f1 = 2 * (precision * recall) / (precision + recall) if (precision + recall) > 0 else 0.0  # BUG_HOOK_F1')
    add('        if f1 > best_f1:')
    add('            best_f1 = f1')
    add('            best_t = float(t)')
    add('    return best_t, float(best_f1)')
    add('')

    add('def semantic_clustering(vectors: np.ndarray, k: int = 3, iters: int = 5) -> Tuple[np.ndarray, np.ndarray]:')
    add('    """Tiny k-means-like clustering for demo; returns (centroids, assignments)."""')
    add('    if vectors.size == 0 or k <= 0:')
    add('        return np.empty((0, 0)), np.empty((0,), dtype=int)')
    add('    k = min(k, max(1, vectors.shape[0]))')
    add('    centroids = vectors[:k, :].copy()  # BUG_HOOK_INIT_CENTROIDS')
    add('    for _ in range(max(1, iters)):')
    add('        dists = np.linalg.norm(vectors[:, None, :] - centroids[None, :, :], axis=2)')
    add('        assign = np.argmin(dists, axis=1)')
    add('        for i in range(k):')
    add('            mask = assign == i')
    add('            if np.any(mask):')
    add('                centroids[i] = np.mean(vectors[mask], axis=0)')
    add('    return centroids, assign')
    add('')

    add('def cross_encoder_rerank(scored: List[Tuple[float, int]], cross_encoder_scores: np.ndarray, alpha: float = 0.5) -> List[int]:')
    add('    """Blend base scores with cross-encoder scores."""')
    add('    ce = np.asarray(cross_encoder_scores, dtype=float)')
    add('    base_scores = np.array([s for s, _ in scored], dtype=float)')
    add('    combined = alpha * ce + (1 - alpha) * base_scores  # BUG_HOOK_CE_INTERACTION')
    add('    order = np.argsort(-combined)')
    add('    return [scored[i][1] for i in order.tolist()]')
    add('')

    add('def query_expansion(query: str, candidates: List[Tuple[str, float]], max_expansions: int = 3) -> List[str]:')
    add('    """Select top textual expansions by weight."""')
    add('    ranked = sorted(candidates, key=lambda x: -x[1])')
    add('    expansions = [w for w, _ in ranked[:max_expansions]]  # BUG_HOOK_EXPANSION')
    add('    return [query] + expansions')
    add('')

    add('def adaptive_chunking(text: str, base_window: int = 120, max_window: int = 240) -> List[str]:')
    add('    """Toy adaptive chunking based on simple punctuation density."""')
    add('    if not text:')
    add('        return []')
    add('    density = text.count(",") + text.count(";") + text.count(":")')
    add('    window = min(max_window, base_window + density)')
    add('    return chunk_document(text, window=window, overlap=20)')
    add('')

    add('def embedding_drift_detection(embeddings: np.ndarray) -> Tuple[float, float]:')
    add('    """Return (score, threshold) where score>threshold indicates drift."""')
    add('    if embeddings.size == 0:')
    add('        return 0.0, 1.0')
    add('    norms = np.linalg.norm(embeddings, axis=1)')
    add('    mean = float(np.mean(norms))')
    add('    std = float(np.std(norms))')
    add('    threshold = mean + 3 * std  # BUG_HOOK_DRIFT_THRESH')
    add('    score = float(abs(norms[-1] - mean))')
    add('    return score, threshold')
    add('')

    # Substantial, realistic utilities and classes to make the file meaty
    bulk = '''
def tokenize(text: str) -> List[str]:
    return [t for t in str(text).lower().split() if t]

def jaccard(a: Sequence[str], b: Sequence[str]) -> float:
    sa, sb = set(a), set(b)
    if not sa and not sb:
        return 1.0
    if not sa or not sb:
        return 0.0
    return len(sa & sb) / float(len(sa | sb))

def cosine_distance(a: np.ndarray, b: np.ndarray) -> float:
    return 1.0 - cosine_sim(a, b)

def softmax(x: Sequence[float]) -> List[float]:
    arr = np.array(list(x), dtype=float)
    if arr.size == 0:
        return []
    m = float(np.max(arr))
    ex = np.exp(arr - m)
    s = float(np.sum(ex)) or 1.0
    return (ex / s).tolist()

def moving_average(x: Sequence[float], window: int = 5) -> List[float]:
    if window <= 0:
        return []
    arr = np.array(list(x), dtype=float)
    if arr.size == 0:
        return []
    cumsum = np.cumsum(np.insert(arr, 0, 0.0))
    out = (cumsum[window:] - cumsum[:-window]) / float(window)
    return out.tolist()

def build_inverted_index(docs: Sequence[str]) -> Dict[str, List[int]]:
    inv: Dict[str, List[int]] = defaultdict(list)
    for i, d in enumerate(docs):
        seen = set()
        for tok in tokenize(d):
            if tok not in seen:
                inv[tok].append(i)
                seen.add(tok)
    return dict(inv)

def compute_tf_idf(tokenized_docs: Sequence[Sequence[str]]) -> Tuple[Dict[str, int], np.ndarray]:
    vocab: Dict[str, int] = {}
    # Build vocab
    for toks in tokenized_docs:
        for t in toks:
            if t not in vocab:
                vocab[t] = len(vocab)
    n_docs = len(tokenized_docs)
    if n_docs == 0:
        return vocab, np.zeros((0, 0), dtype=float)
    # Term frequencies and document frequencies
    tf = np.zeros((n_docs, len(vocab)), dtype=float)
    df = np.zeros((len(vocab),), dtype=float)
    for i, toks in enumerate(tokenized_docs):
        counts = Counter(toks)
        if not counts:
            continue
        max_tf = float(max(counts.values())) or 1.0
        for t, c in counts.items():
            j = vocab[t]
            tf[i, j] = c / max_tf
        for t in set(toks):
            df[vocab[t]] += 1
    idf = np.log((n_docs + 1) / (df + 1)) + 1.0
    tfidf = tf * idf
    return vocab, tfidf

def bm25_score(query_tokens: Sequence[str], doc_tokens: Sequence[str], avgdl: float, k1: float = 1.5, b: float = 0.75) -> float:
    if avgdl <= 0:
        avgdl = 1.0
    q_counts = Counter(query_tokens)
    d_counts = Counter(doc_tokens)
    dl = float(sum(d_counts.values())) or 1.0
    score = 0.0
    for term, qf in q_counts.items():
        f = float(d_counts.get(term, 0))
        if f <= 0:
            continue
        idf = math.log(1 + (1_000_000 - f + 0.5) / (f + 0.5))
        denom = f + k1 * (1 - b + b * (dl / avgdl))
        score += idf * (f * (k1 + 1)) / (denom or 1.0)
    return float(score)

def precision_at_k(true_items: Sequence[int], pred_items: Sequence[int], k: int) -> float:
    if k <= 0:
        return 0.0
    s_true = set(true_items)
    s_pred = pred_items[:k]
    if not s_pred:
        return 0.0
    return float(len(s_true.intersection(s_pred))) / float(len(s_pred))

def recall_at_k(true_items: Sequence[int], pred_items: Sequence[int], k: int) -> float:
    s_true = set(true_items)
    if not s_true:
        return 0.0
    s_pred = set(pred_items[:k])
    return float(len(s_true.intersection(s_pred))) / float(len(s_true))

def dcg(scores: Sequence[float], k: int) -> float:
    s = 0.0
    for i, v in enumerate(scores[:k], start=1):
        s += (2**v - 1) / math.log2(i + 1)
    return float(s)

def ndcg(true_rels: Sequence[float], pred_order: Sequence[int], k: int) -> float:
    ideal = sorted(true_rels, reverse=True)
    ideal_dcg = dcg(ideal, k)
    if ideal_dcg <= 0:
        return 0.0
    ranked = [true_rels[i] for i in pred_order]
    return float(dcg(ranked, k) / ideal_dcg)

@dataclass
class RetrievalConfig:
    top_k: int = 5
    use_cross_encoder: bool = False
    alpha: float = 0.5

class RetrievalPipeline:
    def __init__(self, docs: Sequence[str], config: RetrievalConfig | None = None) -> None:
        self.docs = list(docs)
        self.cfg = config or RetrievalConfig()
        self.inv = build_inverted_index(self.docs)

    def search(self, query: str, doc_embs: Sequence[np.ndarray], query_emb: np.ndarray) -> List[int]:
        order = rank(self.docs, query_emb, list(doc_embs), top_k=self.cfg.top_k)
        return order

    def evaluate(self, queries: Sequence[str], gold: Sequence[Sequence[int]], doc_embs: Sequence[np.ndarray], query_embs: Sequence[np.ndarray]) -> Dict[str, float]:
        precs, recs = [], []
        for q, g, qe in zip(queries, gold, query_embs):
            r = self.search(q, doc_embs, qe)
            precs.append(precision_at_k(g, r, self.cfg.top_k))
            recs.append(recall_at_k(g, r, self.cfg.top_k))
        return {"precision@k": float(np.mean(precs) if precs else 0.0), "recall@k": float(np.mean(recs) if recs else 0.0)}
'''
    for _line in bulk.splitlines():
        add(_line)
    add('')

    add('def _noop(*args, **kwargs):\n    return None')
    add('')
    helper_block = textwrap.dedent('''
    def _stat_summary(x: Sequence[float]) -> Dict[str, float]:
        arr = np.array(list(x), dtype=float) if x else np.array([], dtype=float)
        if arr.size == 0:
            return {"mean": 0.0, "std": 0.0, "min": 0.0, "max": 0.0}
        return {"mean": float(arr.mean()), "std": float(arr.std()), "min": float(arr.min()), "max": float(arr.max())}

    def _safe_topk(values: Sequence[float], k: int) -> List[int]:
        idx = np.argsort(-np.array(values, dtype=float))
        k = max(0, int(k))
        return idx[:k].tolist()
    ''').strip('\n')

    for i in range(1, 200):
        add(helper_block.replace('topk', f'topk_{i}'))
        add('')
        add(f'# helper repetition {i}')

    # Ensure exactly 2000 lines (accounting for multiline strings already split via add)
    content = '\n'.join(lines) + '\n'
    # Adjust by actual line count
    line_list = content.splitlines()
    if len(line_list) < 2000:
        line_list.extend(['# padding'] * (2000 - len(line_list)))
    elif len(line_list) > 2000:
        line_list = line_list[:2000]
    return '\n'.join(line_list) + '\n'

Path('src/retrieval_pipeline.py').write_text(build_content())
print('Wrote extended src/retrieval_pipeline.py')
PY
    cat > tests/test_retrieval.py <<'EOF'
import numpy as np
from src.retrieval_pipeline import cosine_sim, rank

def test_cosine_sim_normalizes():
    a = np.array([1.0, 0.0]); b = np.array([10.0, 0.0])
    assert abs(cosine_sim(a,b) - 1.0) < 1e-6

def test_rank_descending_and_count():
    q = np.array([1.0, 0.0])
    docs = ["a","b","c","d"]
    embs = [np.array([1.0,0.0]), np.array([0.9,0.1]), np.array([0.0,1.0]), np.array([0.7,0.3])]
    out = rank(docs, q, embs, top_k=3)
    assert len(out) == 3
    # ensure first is most similar (index 0)
    assert out[0] == 0
    # ensure sorting is descending by similarity (index 2 is least similar)
    assert out[-1] != 2
    # ensure no off-by-one exclusion of the kth item
    out2 = rank(docs, q, embs, top_k=4)
    assert len(out2) == 4

def test_rank_returns_correct_count():
    """Test that rank returns exactly top_k items, not top_k-1"""
    docs = ["a", "b", "c", "d", "e"]
    q = np.array([1.0, 0.0])
    embs = [np.array([i, 0.0]) for i in range(5)]
    for k in [1, 2, 3, 4, 5]:
        result = rank(docs, q, embs, top_k=k)
        assert len(result) == k, f"Expected {k} results, got {len(result)}"

def test_rank_sort_order():
    """Test that rank sorts by similarity in descending order"""
    docs = ["low", "high", "med"]
    q = np.array([1.0, 0.0])
    embs = [
        np.array([0.1, 0.0]),  # low similarity
        np.array([1.0, 0.0]),  # high similarity
        np.array([0.5, 0.0])   # medium similarity
    ]
    result = rank(docs, q, embs, top_k=3)
    # Should be [1, 2, 0] (high, med, low)
    assert result[0] == 1, f"Expected highest similarity first, got {result}"
    assert result[-1] == 0, f"Expected lowest similarity last, got {result}"

# Additional comprehensive tests to catch all bug types
def test_cosine_sim_scale_invariant():
    """Scale invariance test - catches normalization bugs"""
    a = np.array([1.0, 0.0])
    b = np.array([10.0, 0.0])  # Same direction, 10x magnitude
    assert abs(cosine_sim(a, b) - 1.0) < 1e-6

def test_cosine_sim_no_bias():
    """No bias test - catches added constants"""
    a = np.array([1.0, 0.0])
    b = np.array([1.0, 0.0])  # Identical vectors
    assert abs(cosine_sim(a, b) - 1.0) < 1e-6

def test_cosine_sim_orthogonal():
    """Orthogonal test - catches wrong calculations"""
    a = np.array([1.0, 0.0])
    b = np.array([0.0, 1.0])
    assert abs(cosine_sim(a, b) - 0.0) < 1e-6

def test_cosine_sim_zero_protection():
    """Zero vector protection test"""
    a = np.array([0.0, 0.0])
    b = np.array([1.0, 0.0])
    result = cosine_sim(a, b)
    assert not np.isnan(result) and not np.isinf(result)

def test_rank_exact_k_items():
    """Test exact k items returned - catches k-1 bugs"""
    docs = ["a", "b", "c", "d", "e"]
    q = np.array([1.0, 0.0])
    embs = [np.array([float(5-i), 0.0]) for i in range(5)]
    result = rank(docs, q, embs, top_k=3)
    assert len(result) == 3, f"Expected 3 items, got {len(result)}"

def test_rank_includes_best():
    """Test best result included - catches indexing bugs"""
    docs = ["worst", "best"]  
    q = np.array([1.0, 0.0])
    embs = [np.array([0.0, 1.0]), np.array([1.0, 0.0])]  # worst, best
    result = rank(docs, q, embs, top_k=1)
    assert result[0] == 1, f"Best should be index 1, got {result[0]}"

def test_rank_similarity_not_distance():
    """Test similarity vs distance - catches 1.0-x bugs"""
    docs = ["close", "far"]
    q = np.array([1.0, 0.0])
    embs = [np.array([1.0, 0.0]), np.array([0.0, 1.0])]  # sim=1.0, sim=0.0
    result = rank(docs, q, embs, top_k=2)
    assert result[0] == 0, f"Close should be first, got {result[0]}"

def test_rank_no_scaling():
    """Test no artificial scaling - catches multiplication bugs"""
    docs = ["perfect"]
    q = np.array([1.0, 0.0])
    embs = [np.array([1.0, 0.0])]  # Perfect match
    result = rank(docs, q, embs, top_k=1)
    assert result[0] == 0, "Perfect match should rank first"

def test_rank_zero_indexing():
    """Test zero-based indexing - catches enumerate(start=1) bugs"""
    docs = ["first", "second"]
    q = np.array([1.0, 0.0])
    embs = [np.array([1.0, 0.0]), np.array([0.5, 0.0])]
    result = rank(docs, q, embs, top_k=2)
    assert 0 in result, f"Should contain index 0, got {result}"

def test_rank_various_k():
    """Test multiple k values - comprehensive off-by-one detection"""
    docs = [f"doc{i}" for i in range(6)]
    q = np.array([1.0, 0.0])
    embs = [np.array([1.0-i*0.1, 0.0]) for i in range(6)]
    for k in [1, 2, 3, 4, 5, 6]:
        result = rank(docs, q, embs, top_k=k)
        assert len(result) == k, f"k={k}: expected {k} results, got {len(result)}"
        assert result[0] == 0, f"k={k}: best result should be first"
EOF

    # Ensure imports work even if PYTHONPATH is not propagated by the runner
    cat > tests/conftest.py <<'PY'
import os, sys
root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
if root not in sys.path:
    sys.path.insert(0, root)
src = os.path.join(root, 'src')
if src not in sys.path:
    sys.path.insert(0, src)
PY

    # Additional tests to ensure regressions are detected across the pipeline
    cat > tests/test_retrieval_extended.py <<'EOF'
import numpy as np
from src.retrieval_pipeline import (
    compute_embedding_quality,
    optimize_retrieval_threshold,
    semantic_clustering,
    cross_encoder_rerank,
    query_expansion,
    embedding_drift_detection,
    chunk_document,
)


def test_compute_embedding_quality_variance_positive():
    """Test that variance is calculated correctly, not forced to 0"""
    vecs = [np.array([1.0, 0.0]), np.array([0.0, 1.0]), np.array([0.5, 0.5])]
    m = compute_embedding_quality(vecs)
    # With different norm vectors, variance should be > 0
    assert m['variance'] > 0.0, f"Expected variance > 0, got {m['variance']}"


def test_optimize_retrieval_threshold_uses_f1():
    """Test that F1 score is calculated as harmonic mean, not arithmetic sum"""
    y_true = [1, 0, 1, 0]
    scores = [0.9, 0.1, 0.8, 0.2]
    t, f1 = optimize_retrieval_threshold(y_true, scores)
    
    # With threshold around 0.5, we should get precision=1.0, recall=0.5
    # Correct F1 = 2 * (1.0 * 0.5) / (1.0 + 0.5) = 0.67
    # Wrong F1 = 1.0 + 0.5 = 1.5
    # The returned F1 should be <= 1.0 (impossible with arithmetic sum)
    assert f1 <= 1.0, f"F1 score should be <= 1.0, got {f1}"
    best = -1.0
    for th in np.linspace(0.0, 1.0, 51):
        yp = (sc >= th).astype(int)
        tp = int(np.sum((yp == 1) & (ys == 1)))
        fp = int(np.sum((yp == 1) & (ys == 0)))
        fn = int(np.sum((yp == 0) & (ys == 1)))
        prec = tp / (tp + fp) if (tp + fp) > 0 else 0.0
        rec = tp / (tp + fn) if (tp + fn) > 0 else 0.0
        f1_true = 2 * (prec * rec) / (prec + rec) if (prec + rec) > 0 else 0.0
        best = max(best, f1_true)
    assert abs(f1 - best) < 1e-6


def test_semantic_clustering_centroids_not_zero_matrix():
    """Test that centroids are initialized from data, not as zeros"""
    X = np.array([[1.0, 0.0], [0.9, 0.1], [0.0, 1.0], [0.1, 0.9]])
    C, assign = semantic_clustering(X, k=2, iters=0)  # 0 iters to test initialization
    # Centroids should be initialized from actual data, not all zeros
    assert np.any(C != 0.0), f"Centroids should not all be zero, got {C}"


def test_cross_encoder_rerank_blends_base_scores():
    # With alpha=0, ranking must reflect base scores only
    scored = [(0.5, 0), (0.5, 1)]
    ce = np.array([0.0, 1.0])
    order = cross_encoder_rerank(scored, ce, alpha=0.0)
    # If base scores tie, preserve original order 0 before 1
    assert order[0] == 0


def test_query_expansion_respects_max_expansions():
    """Test that query expansion returns max_expansions terms, not just 1"""
    cands = [("x", 0.9), ("y", 0.8), ("z", 0.7), ("w", 0.6)]
    result = query_expansion("q", cands, max_expansions=3)
    # Should return query + 3 expansions = 4 total
    assert len(result) == 1 + 3, f"Expected 4 terms, got {len(result)}"
    
def test_query_expansion_uses_all_candidates():
    """Test that query expansion doesn't limit to just 1 candidate"""
    cands = [("x", 0.9), ("y", 0.8), ("z", 0.7)]
    result = query_expansion("q", cands, max_expansions=2)
    # Should include "x" and "y", not just "x"
    assert "y" in result, f"Expected 'y' in result, got {result}"


def test_drift_threshold_is_mean_plus_3std():
    E = np.array([[1.0, 0.0], [2.0, 0.0], [4.0, 0.0], [8.0, 0.0]])
    _, thr = embedding_drift_detection(E)
    norms = np.linalg.norm(E, axis=1)
    mu = float(np.mean(norms))
    sig = float(np.std(norms))
    assert abs(thr - (mu + 3 * sig)) < 1e-6


def test_chunk_document_overlap_math():
    # Construct a unique text where positions are unambiguous
    text = ''.join(f"{i:03d}" for i in range(150))
    window, overlap = 30, 5
    chunks = chunk_document(text, window=window, overlap=overlap)
    assert len(chunks) >= 2
    first, second = chunks[0], chunks[1]
    expected_start = len(first) - overlap
    actual_start = text.find(second)
    assert actual_start == expected_start
EOF

    # Ensure requirements include numpy/pytest if not present
    if [ ! -f requirements.txt ]; then
        cat > requirements.txt << 'REQ'
numpy
pytest
pytest-json-report
REQ
    fi

    # Ensure pytest discovers tests and can import from src
    cat > pytest.ini <<'PYTEST'
[pytest]
testpaths = tests
pythonpath = .
addopts = -q --disable-warnings
PYTEST
    touch src/__init__.py
}

main() {
    detect_terminal; setup_visuals; banner

    # Dependencies
    for c in gh git python3; do need "$c"; done
    
    # Verify GitHub authentication
    if ! gh auth status >/dev/null 2>&1; then
        err "GitHub CLI not authenticated. Please authenticate using 'gh auth login'"
        exit 1
    fi
    
    # Validate NUM_BUGS parameter
    if ! [[ "$NUM_BUGS" =~ ^[0-9]+$ ]] || [ "$NUM_BUGS" -lt 1 ] || [ "$NUM_BUGS" -gt 6 ]; then
        err "Invalid --bugs value: $NUM_BUGS. Must be a number between 1 and 6."
        exit 1
    fi

    # Repo root and workflow templates
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    # Canonical template lives at quickstart/.github/workflows/nova.yml (relative to this script)
    if [ -f "$SCRIPT_DIR/../.github/workflows/nova.yml" ]; then
        CI_TEMPLATE="$SCRIPT_DIR/../.github/workflows/nova.yml"
    else
        err "Template missing: expected quickstart/.github/workflows/nova.yml"
        exit 1
    fi

    # Determine owner - default to 'joinnova-ci' unless provided via --org
    if [ -z "${ORG_OR_USER:-}" ]; then
        ORG_OR_USER="joinnova-ci"
    fi

    # Repo name
    if [ -z "$REPO_NAME" ]; then REPO_NAME="nova-quickstart-$(date +%Y%m%d-%H%M%S)"; fi
    local FULL_NAME="$ORG_OR_USER/$REPO_NAME"

    # API key
    if [ -z "${OPENAI_API_KEY:-}" ]; then
        if [ -f "$HOME/.nova.env" ]; then source "$HOME/.nova.env" || true; fi
    fi
    if [ -z "${OPENAI_API_KEY:-}" ]; then
        if [ "$FORCE_YES" = true ]; then err "OPENAI_API_KEY not set in env; export it before running with --yes"; exit 1; fi
        echo -e "${DIM}Get an API key at https://platform.openai.com/api-keys${NC}"
        printf "${BOLD}Enter OPENAI_API_KEY:${NC} "; read -rs OPENAI_API_KEY; echo
        export OPENAI_API_KEY
    fi

    # Workspace
    step 1 7 "Create isolated workspace" "$PACKAGE"
    WORKDIR="/tmp/$REPO_NAME"; rm -rf "$WORKDIR" 2>/dev/null || true; mkdir -p "$WORKDIR"; cd "$WORKDIR"
    ok "Workspace: $WORKDIR"

    # Create virtual environment and install Nova
    step 2 7 "Install Nova CI-Rescue" "$ROCKET"
    
    # Create virtual environment with error handling
    if python3 -m venv .venv; then
        # Activate virtual environment 
        source .venv/bin/activate
        # Upgrade pip in virtual environment
        python -m pip install --quiet --upgrade pip
        
        # Install latest Nova only (pin to latest from Cloudsmith to avoid resolver backtracking)
        INDEX_URL="https://dl.cloudsmith.io/T99gON7ReiBu6hPP/nova/nova-ci-rescue/python/simple/"
        LATEST_VER=$(python -m pip index versions nova-ci-rescue --index-url "$INDEX_URL" 2>/dev/null | head -1 | sed -E 's/.*\(([^)]+)\).*/\1/')
        if [ -n "$LATEST_VER" ]; then
            python -m pip install --quiet --no-cache-dir "nova-ci-rescue==${LATEST_VER}" \
                --index-url "$INDEX_URL" \
                --extra-index-url "https://pypi.org/simple" \
                2>&1 | grep -v "Requirement already satisfied" || true
        else
            # Fallback to unpinned latest if pip index is unavailable
            python -m pip install --quiet --no-cache-dir nova-ci-rescue \
                --index-url "$INDEX_URL" \
                --extra-index-url "https://pypi.org/simple" \
                2>&1 | grep -v "Requirement already satisfied" || true
        fi
    else
        # Fallback to system python if venv creation fails
        warn "Virtual environment creation failed, using system python"
        python3 -m pip install --user --quiet --upgrade pip || true
        python3 -m pip install --user --quiet nova-ci-rescue || true
    fi
    ok "Nova installed"

    # Seed demo content
    step 3 7 "Create working project" "$BRAIN"
    if [ "$DEMO_KIND" = "retrieval" ]; then
        info "Creating retrieval project (will inject $NUM_BUGS bug$([ "$NUM_BUGS" -eq 1 ] && echo "" || echo "s"))"
        seed_retrieval_demo
    else
        info "Creating Top-K retriever project"
        mkdir -p src/rag tests
        touch tests/__init__.py src/__init__.py src/rag/__init__.py
        cat > src/rag/retriever.py << 'EOF'
from typing import Callable, List, Sequence, Tuple, Any

ScoreFn = Callable[[str, Any], float]
Triple = Tuple[int, Any, float]

def _default_score(q: str, d: Any) -> float:
    qt = set(str(q).lower().split())
    dt = set(str(d).lower().split())
    if not qt and not dt:
        return 1.0
    if not qt or not dt:
        return 0.0
    inter = len(qt & dt)
    union = len(qt | dt) or 1
    return inter / union

def retrieve_top_k(query: str,
                   corpus: Sequence[Any],
                   k: int = 5,
                   score_fn: ScoreFn | None = None) -> List[Triple]:
    if k is None or k <= 0:
        return []
    sf = score_fn or _default_score
    results: List[Triple] = []
    for i, doc in enumerate(corpus):
        s = float(sf(query, doc))
        # Keep zero-score docs in the pool; caller controls k
        results.append((i, doc, s))
    # Sort by score descending; tie-break by index ascending
    results.sort(key=lambda t: (-t[2], t[0]))
    # Return exactly min(k, len(corpus))
    return results[: min(max(0, k), len(corpus))]
EOF
        cat > tests/test_retriever.py << 'EOF'
import math
from src.rag.retriever import retrieve_top_k

CORPUS = [
    "red fox jumps",      # idx 0
    "blue fox sleeps",    # idx 1
    "green turtle swims", # idx 2
    "fox red red",        # idx 3 (ties w/ 0 but higher score)
    "zebra"               # idx 4 (often zero score)
]

def test_includes_zero_scores_and_exact_k():
    res = retrieve_top_k("red fox", CORPUS, k=3)
    assert len(res) == 3
    assert all(len(t) == 3 for t in res)
    assert all(isinstance(t[2], float) for t in res)

def test_sorted_desc_then_index_asc():
    res = retrieve_top_k("red fox", CORPUS, k=3)
    scores = [t[2] for t in res]
    assert scores == sorted(scores, reverse=True)
    for (i1, _, s1), (i2, _, s2) in zip(res, res[1:]):
        if math.isclose(s1, s2):
            assert i1 < i2

def test_k_greater_than_len_corpus():
    res = retrieve_top_k("nothing", ["a", "b"], k=10)
    assert len(res) == 2

def test_k_zero_or_negative_is_empty():
    assert retrieve_top_k("x", CORPUS, k=0) == []
    assert retrieve_top_k("x", CORPUS, k=-1) == []

def test_result_triplet_shapes():
    res = retrieve_top_k("fox", CORPUS, k=2)
    for idx, doc, score in res:
        assert isinstance(idx, int)
        assert isinstance(doc, str)
        assert isinstance(score, float)
EOF
    fi
    ok "Working project created"

    # Ensure dependency manifest exists; keep retrieval requirements if present
    if [ ! -f requirements.txt ]; then
        if [ "$DEMO_KIND" = "topk" ]; then
            cat > requirements.txt << 'EOF'
pytest
pytest-json-report
EOF
        fi
    fi

    # Add CI workflow with Nova auto-fix
    step 4 7 "Add CI workflow with Nova auto-fix" "$ROCKET"
    mkdir -p .github/workflows
    # (Optional) Sticky helper kept for backward-compat; workflow updater is canonical
    mkdir -p scripts
    cat > scripts/nova_sticky_comment.sh <<'STICKY'
#!/usr/bin/env bash
set -euo pipefail
TITLE="${1:-Nova CI-Rescue}"
BODY="${2:-}" 
TAG="<!-- NOVA_STICKY_COMMENT -->"
pr_number="${PR_NUMBER:-${GITHUB_REF##*/}}"
cid="$(gh api repos/${GITHUB_REPOSITORY}/issues/${pr_number}/comments --jq ".[] | select(.body|contains(\"$TAG\")) | .id" | head -n1 || true)"
markdown="### ${TITLE}
${TAG}

${BODY}
"
if [ -n "${cid}" ]; then
  gh api repos/${GITHUB_REPOSITORY}/issues/comments/${cid} -X PATCH -f body="${markdown}" >/dev/null
else
  gh api repos/${GITHUB_REPOSITORY}/issues/${pr_number}/comments -f body="${markdown}" >/dev/null
fi
echo "Sticky comment updated."
STICKY
    chmod +x scripts/nova_sticky_comment.sh

    # Prefer the vetted quickstart workflow template to avoid YAML drift
    if [ -f "$SCRIPT_DIR/../.github/workflows/nova.yml" ]; then
      cp "$SCRIPT_DIR/../.github/workflows/nova.yml" .github/workflows/nova.yml
    else
      echo "::error::quickstart/.github/workflows/nova.yml not found" >&2
      terminate 1
    fi

    # Add pytest.ini to help test discovery and Python path
    cat > pytest.ini <<'PYTEST'
[pytest]
testpaths = tests
pythonpath = .
addopts = -q --disable-warnings
PYTEST

    # Add setup.py for proper package installation
    cat > setup.py <<'SETUP'
from setuptools import setup, find_packages

setup(
    name="nova-demo-project",
    version="0.1.0",
    packages=find_packages(),
    install_requires=[
        "numpy",
        "pytest",
        "pytest-json-report",
    ],
)
SETUP
    ok "Workflow installed"

    # Ensure artifacts and CI-only files are not committed as source changes
    cat > .gitignore <<'GIT'
# Nova / CI outputs
.nova/
.nova-ci/
test-results.json
coverage.xml
*.coverage
*.pytest_cache/
__pycache__/
*.pyc

# Python package build artifacts
*.egg-info/
build/
dist/
GIT

    # Provide minimal Nova configuration required by CI checks
    mkdir -p .nova-ci
    MODEL_VALUE="${NOVA_DEFAULT_LLM_MODEL:-gpt-5-mini}"
    EFFORT_VALUE="${NOVA_DEFAULT_REASONING_EFFORT:-high}"
    cat > .nova-ci/config.json <<'EOF'
{
  "language": "python",
  "install": [
    "python -m pip install -U pip",
    "pip install -r requirements.txt"
  ],
  "test_command": "PYTHONPATH=. pytest -v --json-report --json-report-file test-results.json",
  "llm": {
    "model": "gpt-5-mini",
    "reasoning_effort": "high"
  },
  "safety": {
    "max_patch_lines": 200,
    "max_patch_files": 5,
    "max_iters": 3
  },
  "pr": {
    "auto_create": false
  },
  "nova": {
    "package": "nova-ci-rescue",
    "index_url": "https://dl.cloudsmith.io/T99gON7ReiBu6hPP/nova/nova-ci-rescue/python/simple/",
    "version": "",
    "fix_args": "--ci-mode --patch-mode --max-iters 3 --timeout 900 --verbose",
    "safety_env": {
      "NOVA_SAFETY_MAX_FILES": "5",
      "NOVA_SAFETY_MAX_LINES_PER_FILE": "3000"
    }
  }
}
EOF
    ok "Nova CI config created (.nova-ci/config.json)"

    # Init repo and create on GitHub
    step 5 7 "Create GitHub repo and push" "$ROCKET"
    git init -q
    git config user.name "Nova Demo Bot"
    git config user.email "demo@joinnova.com"
    # Ensure ephemeral outputs are ignored by default
    cat > .gitignore <<'EOF'
.nova/
test-results.json
__pycache__/
*.py[cod]
EOF
    git branch -M main
    git add -A
    git commit -qm "feat: working Top-K retriever with CI"
    VISIBILITY="--private"; [ "$PUBLIC" = true ] && VISIBILITY="--public"
    
    # Check if repo exists
    if gh repo view "$FULL_NAME" >/dev/null 2>&1; then
        info "Repo exists: $FULL_NAME"
        # Remove existing remote if any, then add fresh
        git remote remove origin 2>/dev/null || true
        git remote add origin "https://github.com/$FULL_NAME.git"
        # Ensure git uses gh keyring credentials for push
        git config credential.https://github.com.helper "" || true
        git config credential.https://github.com "!gh auth git-credential" || true
        # Push to existing repo with conflict resolution
        if ! git push -u origin main 2>/dev/null; then
            warn "Push conflict detected, resolving..."
            # Pull remote changes and merge
            git pull origin main --no-edit || {
                # If pull fails, force push (overwrites remote)
                warn "Pull failed, force pushing to reset remote repo"
                git push -u origin main --force
            }
            # Try push again after pull
            git push -u origin main || {
                err "Failed to push after conflict resolution"
                exit 1
            }
        fi
    else
        info "Creating new repo: $FULL_NAME"
        # Create repo WITHOUT --push flag to avoid remote conflicts
        if ! gh repo create "$FULL_NAME" $VISIBILITY >/dev/null 2>&1; then
            # If creation in org fails due to permissions, retry under user account
            ME=$(gh api user -q .login 2>/dev/null || echo "")
            if [ -n "$ME" ] && [[ "$FULL_NAME" == joinnova-ci/* ]]; then
                warn "Org creation failed; retrying under $ME namespace."
                ORG_OR_USER="$ME"
                FULL_NAME="$ORG_OR_USER/$REPO_NAME"
                gh repo create "$FULL_NAME" $VISIBILITY || {
                    err "Failed to create GitHub repo. Check permissions and try again."
                    echo "  - Ensure your token has 'repo' scope"
                    echo "  - Try: gh auth status"
                    exit 1
                }
            else
                err "Failed to create GitHub repo. Check permissions and try again."
                echo "  - Ensure your token has 'repo' scope"
                echo "  - Try: gh auth status"
                exit 1
            fi
        fi
        
        # Disable repository rules to prevent push blocking
        gh api repos/$FULL_NAME --method PATCH \
            -f secret_scanning_enabled=false \
            -f secret_scanning_push_protection_enabled=false >/dev/null 2>&1 || true
        
        # Set up GitHub secrets from .nova.env if it exists
        if [ -f "$HOME/.nova.env" ]; then
            info "Setting up GitHub secrets from .nova.env..."
            # Source the env file to get the values
            set -a  # Export all vars
            source "$HOME/.nova.env"
            set +a
            # Force keyring-backed gh auth by clearing env tokens if present
            unset GH_TOKEN || true
            unset GITHUB_TOKEN || true
            
            # Set ANTHROPIC_API_KEY if present  
            if [ ! -z "$ANTHROPIC_API_KEY" ]; then
                gh secret set ANTHROPIC_API_KEY --repo "$FULL_NAME" --body "$ANTHROPIC_API_KEY" || true
            fi
        else
            warn "No .nova.env file found - GitHub secrets not configured"
        fi
        # Check if remote was already added by gh repo create
        if ! git remote get-url origin >/dev/null 2>&1; then
            # Only add remote if it doesn't exist
            git remote add origin "https://github.com/$FULL_NAME.git"
        fi
        # Ensure git uses gh keyring credentials for push
        git config credential.https://github.com.helper "" || true
        git config credential.https://github.com "!gh auth git-credential" || true
        # Push to the repo with error handling
        if ! git push -u origin main 2>/dev/null; then
            warn "Initial push failed, attempting conflict resolution..."
            # Try pulling first in case repo has initial commit
            git pull origin main --no-edit --allow-unrelated-histories || {
                warn "Pull failed, force pushing to initialize repo"
                git push -u origin main --force
            }
        fi
    fi
    ok "Pushed to https://github.com/$FULL_NAME"

    # Prefer nova-bot on org repos: seed NOVA_BOT_TOKEN secret if available
    if [ "$ORG_OR_USER" = "joinnova-ci" ]; then
        if [ -z "${NOVA_BOT_TOKEN:-}" ] && [ -f "$HOME/.nova.env" ]; then
            set -a; source "$HOME/.nova.env" 2>/dev/null || true; set +a
        fi
        if [ -n "${NOVA_BOT_TOKEN:-}" ]; then
            gh secret set NOVA_BOT_TOKEN --repo "$FULL_NAME" --body "$NOVA_BOT_TOKEN" >/dev/null 2>&1 || true
            ok "Secret NOVA_BOT_TOKEN set on $FULL_NAME"
        else
            note "NOVA_BOT_TOKEN not present; CI will post as github-actions[bot]"
        fi
    else
        note "Using default github-actions[bot] for comments/labels on $FULL_NAME"
    fi

    # Set secrets (OPENAI_API_KEY required, NOVA_BOT_TOKEN optional for custom bot identity)
    step 6 7 "Configure repo secrets" "$KEY"
    gh secret set OPENAI_API_KEY --repo "$FULL_NAME" --body "$OPENAI_API_KEY" >/dev/null
    if [ -n "${NOVA_BOT_TOKEN:-}" ]; then
        gh secret set NOVA_BOT_TOKEN --repo "$FULL_NAME" --body "$NOVA_BOT_TOKEN" >/dev/null || true
        info "Set NOVA_BOT_TOKEN for custom comment identity"
    else
        warn "NOVA_BOT_TOKEN not set; comments will appear from GitHub Actions"
    fi
    ok "Secrets configured"

    # Create PR with intentional issues
    step 7 7 "Create PR with broken code → Watch Nova fix it" "$PR"
    # Use clearer branch names per demo kind
    if [ "$DEMO_KIND" = "retrieval" ]; then
        BRANCH_NAME="fix/retrieval-bugs"
    else
        BRANCH_NAME="fix/retriever-bugs"
    fi
    git checkout -b "$BRANCH_NAME"
    
    if [ "$DEMO_KIND" = "retrieval" ]; then
        # Apply intentional regressions via robust regex (ignore spacing/comments)
        NUM_BUGS="$NUM_BUGS" python - <<PY
from pathlib import Path
import re
import os

p = Path('src/retrieval_pipeline.py')
s = p.read_text()

# Get number of bugs from environment variable
num_bugs = int(os.environ.get('NUM_BUGS', 6))

subs = [
    # Cosine regressions (do NOT break zero-protection on 'a')
    (r'(\s+)b_norm = b / \(np\.linalg\.norm\(b\) or 1\.0\)', r'\1b_norm = b'),  # remove normalization on b
    (r'return\s+float\(np\.dot\(a_norm,\s*b_norm\)\)', r'return float(np.dot(a_norm, b_norm)) + 0.1'),  # add bias

    # Ranking regressions
    (r'reverse=True', r'reverse=False'),                      # ascending order
    (r'cosine_sim\(query_embedding,\s*e\)', r'(1.0 - cosine_sim(query_embedding, e))'),  # use distance not similarity
    (r'enumerate\(doc_embeddings\)', r'enumerate(doc_embeddings, 1)'),  # 1-based indices

    # Metric regression (variance forced to 0)
    (r'np\.var\(vs\)', r'0.0'),
]

# Limit substitutions to the requested number of bugs
subs_to_apply = subs[:num_bugs]
print(f'Applying {len(subs_to_apply)} out of {len(subs)} available bug patterns')

changed = 0
for i, (pat, rep) in enumerate(subs_to_apply, 1):
    if changed >= num_bugs:
        print(f'Bug limit reached ({num_bugs}), stopping')
        break
    
    # Limit substitutions to prevent multiple matches for the same pattern
    remaining_bugs = num_bugs - changed
    s, n = re.subn(pat, rep, s, count=remaining_bugs, flags=re.MULTILINE)
    changed += n
    if n > 0:
        print(f'Bug {i}: Applied regression pattern (found {n} matches)')
    else:
        print(f'Bug {i}: Pattern not found in code')

p.write_text(s)
print(f'Applied {changed} total regex regressions to {p}')
if changed == 0:
    print("Warning: No bugs were injected - patterns may not match generated code")
PY
        rm -f src/*.bak src/**/*.bak 2>/dev/null || true
    else
        # Break the simple retriever with classic issues (filter zeros, ASC sort, off-by-one slice)
        cat > src/rag/retriever.py << 'EOF'
from typing import Callable, List, Sequence, Tuple, Any

ScoreFn = Callable[[str, Any], float]
Triple = Tuple[int, Any, float]

def _default_score(q: str, d: Any) -> float:
    qt = set(str(q).lower().split())
    dt = set(str(d).lower().split())
    if not qt and not dt:
        return 1.0
    if not qt or not dt:
        return 0.0
    inter = len(qt & dt)
    union = len(qt | dt) or 1
    return inter / union

def retrieve_top_k(query: str,
                   corpus: Sequence[Any],
                   k: int = 5,
                   score_fn: ScoreFn | None = None) -> List[Triple]:
    if k is None or k <= 0:
        return []
    sf = score_fn or _default_score
    results: List[Triple] = []
    for i, doc in enumerate(corpus):
        s = float(sf(query, doc))
        if s > 0:
            results.append((i, doc, s))
    results.sort(key=lambda t: t[2])
    return results[: max(0, k-1)]
EOF
    fi
    
    git add -A
    git commit -m "feat: introduce retriever issues for Nova demo" || true
    
    git push -u origin "$BRANCH_NAME"
    
    # Create PR
    info "Creating PR with broken retriever..."
    PR_TITLE="Demo: Top-K retriever changes (intentionally buggy)"
    PR_BODY="This PR modifies our Top-K retriever to demonstrate Nova's CI auto-fix."
    if [ "$DEMO_KIND" = "retrieval" ]; then
        PR_TITLE="🚀 Optimize Retrieval Pipeline Performance (intentionally buggy)"
        PR_BODY="This PR introduces performance-oriented regressions in the retrieval pipeline to demonstrate Nova's CI auto-fix."
    fi
    BODY_FILE="$(mktemp)"
    {
        printf "%s\n\n" "$PR_BODY"
        cat <<'EOF'
## What's Changed
- Intentional issues: filters out zero-score docs, sorts ascending without tie-breaker, and returns k-1 items.

Nova CI-Rescue will automatically fix these issues in CI.

## Testing
Tests will fail initially; Nova will fix them automatically. ✅
EOF
    } >"$BODY_FILE"
    if ! gh pr view --head "$BRANCH_NAME" -R "$FULL_NAME" >/dev/null 2>&1; then
        PR_OUTPUT=$(gh pr create \
            --title "$PR_TITLE" \
            --body-file "$BODY_FILE" \
            --base main \
            --head "$BRANCH_NAME" \
            -R "$FULL_NAME" 2>&1)
    else
        PR_OUTPUT=$(gh pr view --json url -R "$FULL_NAME" --jq .url 2>/dev/null || true)
    fi
    rm -f "$BODY_FILE"
    
    # Extract PR URL from output
    PR_URL=$(echo "$PR_OUTPUT" | grep -oE 'https://github.com/[^[:space:]]+/pull/[0-9]+' | head -1)
    
    if [ -n "$PR_URL" ]; then
        ok "Created PR: $PR_URL"
        if [ "$OPEN_PR" = true ]; then
            open_url "$PR_URL" || true
        fi
        # Never auto-open a new browser/terminal here; only print the URL
        info "PR URL: $PR_URL"
        info "Waiting for CI to fail and Nova to auto-fix..."
        
        # Monitor for Nova's fix
        echo
        info "Monitoring for Nova's automatic fix..."
        ATTEMPTS=0; MAX_ATTEMPTS=120
        while [ $ATTEMPTS -lt $MAX_ATTEMPTS ]; do
            # Check if Nova has pushed a fix (stay in this shell; ignore gh errors)
            COMMITS=$(gh pr view "$PR_URL" --json commits --jq '.commits | length' 2>/dev/null || echo 0)
            if [ "${COMMITS:-0}" -gt 1 ]; then
                ok "Nova has pushed a fix! Check the PR for details."
                break
            fi
            ATTEMPTS=$((ATTEMPTS+1))
            sleep 5
            printf "."
        done
    else
        err "Failed to create PR"
        echo "gh pr create output:"
        echo "$PR_OUTPUT"
        echo
        echo "Attempting alternative PR creation..."
        # Try without the -R flag
        PR_URL=$(gh pr create \
            --title "Demo: Top-K retriever changes (intentionally buggy)" \
            --body "This PR modifies our Top-K retriever to demonstrate Nova's CI auto-fix." \
            --base main \
            --head "$BRANCH_NAME" \
            --web=false)
        if [ $? -eq 0 ] && [ -n "$PR_URL" ]; then
            ok "Created PR: $PR_URL"
        else
            err "Alternative PR creation also failed"
            exit 1
        fi
    fi

    echo
    thr
    echo -e "${BOLD}${GREEN}${SPARKLE} Demo complete.${NC} Review and merge the PR to see CI turn green."
    thr
}

# Cleanup function
cleanup() {
    local exit_code=$?
    
    # Deactivate virtual environment if active
    if [ -n "${VIRTUAL_ENV:-}" ]; then
        deactivate 2>/dev/null || true
    fi
    
    # Only show messages if appropriate
    if [ $exit_code -eq 130 ]; then
        # User pressed Ctrl+C
        echo
        echo -e "${YELLOW}Demo interrupted by user${NC}"
        echo -e "${DIM}Thank you for trying Nova CI-Rescue${NC}"
    elif [ $exit_code -ne 0 ]; then
        # Actual error
        echo
        echo -e "${RED}Demo encountered an error (exit code: $exit_code)${NC}"
        echo -e "${DIM}Thank you for trying Nova CI-Rescue${NC}"
    fi
    # If exit_code is 0, demo completed successfully - no cleanup message needed
    
    exit $exit_code
}

# Set trap for cleanup
trap cleanup EXIT INT TERM

main "$@"
