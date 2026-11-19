-- Base vectorial de Rodado en Supabase (pgvector).
-- Pegar entero en Supabase → SQL Editor → Run.

-- 1. La extensión de vectores.
create extension if not exists vector;

-- 2. La tabla donde n8n guarda los fragmentos de los manuales.
--    "vector" sin dimensión fija: sirve para cualquier modelo de embeddings
--    (gemini-embedding-001 da 3072). Con pocos documentos no hace falta índice.
create table if not exists documents (
  id bigserial primary key,
  content text,
  metadata jsonb,
  embedding vector
);

-- 3. Seguridad: nadie entra a la tabla desde la API pública. n8n usa la
--    service_role key, que pasa por encima de esta regla.
alter table documents enable row level security;

-- 4. La búsqueda por similitud que usa el nodo Supabase Vector Store de n8n.
create or replace function match_documents (
  query_embedding vector,
  match_count int default null,
  filter jsonb default '{}'
) returns table (
  id bigint,
  content text,
  metadata jsonb,
  similarity float
)
language plpgsql
as $$
#variable_conflict use_column
begin
  return query
  select
    id,
    content,
    metadata,
    1 - (documents.embedding <=> query_embedding) as similarity
  from documents
  where metadata @> filter
  order by documents.embedding <=> query_embedding
  limit match_count;
end;
$$;

-- Para volver a indexar desde cero (antes de correr de nuevo el workflow de indexado):
-- truncate table documents;
