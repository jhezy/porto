<script setup>
import { computed, onMounted, ref } from "vue";
import { supabase } from "../../lib/supabase";

const rows = ref([]);
const categories = ref([]);
const loading = ref(true);
const saving = ref(false);
const error = ref("");
const success = ref("");
const search = ref("");
const editingId = ref(null);
const form = ref(blankForm());
const STORAGE_BUCKET = "portfolio-assets";
const statusFilter = ref("all");
const categoryFilter = ref("all");

const selectedFile = ref(null);
const previewUrl = ref("");
const originalThumbnailUrl = ref("");

function blankForm() {
  return {
    title: "",
    slug: "",
    summary: "",
    description: "",
    category_id: "",
    thumbnail_url: "",
    live_url: "",
    repository_url: "",
    status: "draft",
    featured: false,
    sort_order: 0,
  };
}
const filteredRows = computed(() => {
  const keyword = search.value.toLowerCase().trim();

  return rows.value.filter((row) => {
    const matchesSearch = `${row.title} ${row.slug}`
      .toLowerCase()
      .includes(keyword);

    const matchesStatus =
      statusFilter.value === "all" || row.status === statusFilter.value;

    const matchesCategory =
      categoryFilter.value === "all" ||
      row.category_id === categoryFilter.value;

    return matchesSearch && matchesStatus && matchesCategory;
  });
});
async function loadData() {
  loading.value = true;
  error.value = "";
  const [projectResult, categoryResult] = await Promise.all([
    supabase
      .from("projects")
      .select(
        `
    id,
    title,
    slug,
    summary,
    category_id,
    thumbnail_url,
    status,
    featured,
    sort_order,
    created_at,
    project_categories(name)
  `,
      )
      .order("created_at", { ascending: false }),
    supabase.from("project_categories").select("id,name").order("name"),
  ]);
  if (projectResult.error || categoryResult.error) {
    error.value = (projectResult.error || categoryResult.error).message;
  } else {
    rows.value = projectResult.data || [];
    categories.value = categoryResult.data || [];
  }
  loading.value = false;
}

function clearImageSelection() {
  if (previewUrl.value.startsWith("blob:")) {
    URL.revokeObjectURL(previewUrl.value);
  }

  previewUrl.value = "";
  selectedFile.value = null;
}

function handleFileChange(event) {
  clearImageSelection();

  const file = event.target.files?.[0];
  if (!file) return;

  const allowedTypes = ["image/jpeg", "image/png", "image/webp"];

  if (!allowedTypes.includes(file.type)) {
    error.value = "Format gambar harus JPG, PNG, atau WebP.";
    event.target.value = "";
    return;
  }

  if (file.size > 2 * 1024 * 1024) {
    error.value = "Ukuran gambar maksimal 2 MB.";
    event.target.value = "";
    return;
  }

  error.value = "";
  selectedFile.value = file;
  previewUrl.value = URL.createObjectURL(file);
}

function getStoragePath(url) {
  if (!url) return null;

  try {
    const parsed = new URL(url);
    const marker = `/storage/v1/object/public/${STORAGE_BUCKET}/`;
    const index = parsed.pathname.indexOf(marker);

    if (index === -1) return null;

    return decodeURIComponent(parsed.pathname.slice(index + marker.length));
  } catch {
    return null;
  }
}

async function uploadThumbnail(file) {
  const { data: authData, error: authError } = await supabase.auth.getUser();

  if (authError || !authData.user) {
    throw new Error("Sesi login berakhir. Silakan login kembali.");
  }

  const extensions = {
    "image/jpeg": "jpg",
    "image/png": "png",
    "image/webp": "webp",
  };

  const extension = extensions[file.type];

  // Setiap upload memiliki nama unik agar tidak menimpa file lain.
  const path = `${authData.user.id}/${crypto.randomUUID()}.${extension}`;

  const { error: uploadError } = await supabase.storage
    .from(STORAGE_BUCKET)
    .upload(path, file, {
      contentType: file.type,
      cacheControl: "3600",
      upsert: false,
    });

  if (uploadError) throw uploadError;

  const { data } = supabase.storage.from(STORAGE_BUCKET).getPublicUrl(path);

  return { path, url: data.publicUrl };
}

async function removeThumbnail(url) {
  const path = getStoragePath(url);

  // Jangan menghapus URL eksternal atau file dari bucket lain.
  if (!path) return;

  const { error: removeError } = await supabase.storage
    .from(STORAGE_BUCKET)
    .remove([path]);

  if (removeError) {
    console.error("Gagal menghapus thumbnail:", removeError.message);
  }
}

function makeSlug(value) {
  return value
    .toLowerCase()
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "");
}
function startCreate() {
  clearImageSelection();
  editingId.value = null;
  originalThumbnailUrl.value = "";
  form.value = blankForm();
  error.value = "";
  success.value = "";
}
function startEdit(row) {
  editingId.value = row.id;
  clearImageSelection();
  originalThumbnailUrl.value = row.thumbnail_url || "";
  form.value = {
    title: row.title || "",
    slug: row.slug || "",
    summary: row.summary || "",
    description: row.description || "",
    category_id: row.category_id || "",
    thumbnail_url: row.thumbnail_url || "",
    live_url: row.live_url || "",
    repository_url: row.repository_url || "",
    status: row.status || "draft",
    featured: Boolean(row.featured),
    sort_order: row.sort_order || 0,
  };
  error.value = "";
  success.value = "";
  window.scrollTo({ top: 0, behavior: "smooth" });
}
async function saveProject() {
  error.value = "";
  success.value = "";

  if (!form.value.title.trim()) {
    error.value = "Judul proyek wajib diisi.";
    return;
  }

  if (!form.value.slug.trim()) {
    form.value.slug = makeSlug(form.value.title);
  }

  if (!/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(form.value.slug)) {
    error.value =
      "Slug hanya boleh berisi huruf kecil, angka, dan tanda hubung.";
    return;
  }

  saving.value = true;

  let uploadedPath = null;

  try {
    let thumbnailUrl = form.value.thumbnail_url.trim() || null;

    // Upload hanya dilakukan jika admin memilih gambar baru.
    if (selectedFile.value) {
      const uploaded = await uploadThumbnail(selectedFile.value);
      uploadedPath = uploaded.path;
      thumbnailUrl = uploaded.url;
    }

    const payload = {
      title: form.value.title.trim(),
      slug: form.value.slug.trim(),
      summary: form.value.summary.trim() || null,
      description: form.value.description.trim() || null,
      category_id: form.value.category_id || null,
      thumbnail_url: thumbnailUrl,
      live_url: form.value.live_url.trim() || null,
      repository_url: form.value.repository_url.trim() || null,
      status: form.value.status,
      featured: form.value.featured,
      sort_order: Number(form.value.sort_order) || 0,
      published_at:
        form.value.status === "published" ? new Date().toISOString() : null,
    };

    const wasEditing = Boolean(editingId.value);

    const result = wasEditing
      ? await supabase
          .from("projects")
          .update(payload)
          .eq("id", editingId.value)
      : await supabase.from("projects").insert(payload);

    if (result.error) throw result.error;

    // Hapus gambar lama hanya setelah penyimpanan database berhasil.
    if (
      wasEditing &&
      selectedFile.value &&
      originalThumbnailUrl.value &&
      originalThumbnailUrl.value !== thumbnailUrl
    ) {
      await removeThumbnail(originalThumbnailUrl.value);
    }

    clearImageSelection();
    startCreate();

    success.value = wasEditing
      ? "Proyek berhasil diperbarui."
      : "Proyek berhasil ditambahkan.";

    await loadData();
  } catch (err) {
    // Jika penyimpanan database gagal, bersihkan upload baru yang belum dipakai.
    if (uploadedPath) {
      const { error: cleanupError } = await supabase.storage
        .from(STORAGE_BUCKET)
        .remove([uploadedPath]);

      if (cleanupError) {
        console.error("Pembersihan upload gagal:", cleanupError.message);
      }
    }

    error.value = err.message || "Gagal menyimpan proyek.";
  } finally {
    saving.value = false;
  }
}
async function deleteProject(row) {
  if (
    !window.confirm(
      `Hapus proyek "${row.title}"? Tindakan ini tidak dapat dibatalkan.`,
    )
  ) {
    return;
  }

  error.value = "";
  success.value = "";

  const { error: deleteError } = await supabase
    .from("projects")
    .delete()
    .eq("id", row.id);

  if (deleteError) {
    error.value = deleteError.message;
    return;
  }

  await removeThumbnail(row.thumbnail_url);

  success.value = "Proyek berhasil dihapus.";
  await loadData();
}
onMounted(loadData);
</script>

<template>
  <div class="mb-4">
    <p class="eyebrow mb-2">CONTENT / PROJECTS</p>
    <div
      class="d-flex flex-wrap justify-content-between align-items-start gap-3"
    >
      <div>
        <h1 class="h2 fw-bold mb-1">Pengelolaan proyek</h1>
        <p class="text-muted-custom mb-0">
          Tambah, edit, dan publikasikan karya portofolio.
        </p>
      </div>
      <button
        class="btn btn-accent"
        @click="startCreate"
      >
        <i class="bi bi-plus-lg me-2"></i>Proyek baru
      </button>
    </div>
  </div>

  <div
    v-if="error"
    class="alert alert-danger py-2"
  >
    {{ error }}
  </div>
  <div
    v-if="success"
    class="alert-app mb-3"
  >
    {{ success }}
  </div>

  <div class="panel p-4 mb-4">
    <h2 class="h5 fw-bold mb-3">
      {{ editingId ? "Edit proyek" : "Tambah proyek" }}
    </h2>
    <form
      @submit.prevent="saveProject"
      class="row g-3"
    >
      <div class="col-md-8">
        <label class="form-label small">Judul proyek *</label
        ><input
          v-model="form.title"
          class="form-control"
          required
          maxlength="160"
          @input="
            !editingId && !form.slug ? (form.slug = makeSlug(form.title)) : null
          "
        />
      </div>
      <div class="col-md-4">
        <label class="form-label small">Slug *</label
        ><input
          v-model="form.slug"
          class="form-control"
          required
          pattern="[a-z0-9]+(-[a-z0-9]+)*"
          placeholder="project-saya"
        />
      </div>
      <div class="col-md-6">
        <label class="form-label small">Ringkasan</label
        ><input
          v-model="form.summary"
          class="form-control"
          maxlength="300"
          placeholder="Deskripsi singkat proyek"
        />
      </div>
      <div class="col-md-6">
        <label class="form-label small">Kategori</label
        ><select
          v-model="form.category_id"
          class="form-select"
        >
          <option value="">Tanpa kategori</option>
          <option
            v-for="category in categories"
            :key="category.id"
            :value="category.id"
          >
            {{ category.name }}
          </option>
        </select>
      </div>
      <div class="col-12">
        <label class="form-label small">Deskripsi lengkap</label
        ><textarea
          v-model="form.description"
          class="form-control"
          rows="4"
          placeholder="Masalah, solusi, kontribusi, dan hasil proyek"
        ></textarea>
      </div>
      <div class="col-md-6">
        <label class="form-label small">Gambar thumbnail</label>

        <input
          type="file"
          class="form-control"
          accept="image/jpeg,image/png,image/webp"
          @change="handleFileChange"
        />

        <div class="form-text text-muted-custom">
          JPG, PNG, atau WebP. Maksimal 2 MB.
        </div>

        <div
          v-if="previewUrl || form.thumbnail_url"
          class="mt-3"
        >
          <img
            :src="previewUrl || form.thumbnail_url"
            alt="Preview thumbnail proyek"
            class="img-fluid rounded-3"
            style="max-height: 220px; object-fit: contain"
          />
        </div>
      </div>
      <div class="col-md-4">
        <label class="form-label small">URL demo</label
        ><input
          v-model="form.live_url"
          type="url"
          class="form-control"
          placeholder="https://..."
        />
      </div>
      <div class="col-md-4">
        <label class="form-label small">URL repository</label
        ><input
          v-model="form.repository_url"
          type="url"
          class="form-control"
          placeholder="https://github.com/..."
        />
      </div>
      <div class="col-md-4">
        <label class="form-label small">Status</label
        ><select
          v-model="form.status"
          class="form-select"
        >
          <option value="draft">Draft</option>
          <option value="published">Published</option>
        </select>
      </div>
      <div class="col-md-4">
        <label class="form-label small">Urutan</label
        ><input
          v-model.number="form.sort_order"
          type="number"
          min="0"
          class="form-control"
        />
      </div>
      <div class="col-md-4 d-flex align-items-end pb-2">
        <div class="form-check">
          <input
            id="featured"
            v-model="form.featured"
            class="form-check-input"
            type="checkbox"
          /><label
            for="featured"
            class="form-check-label"
            >Proyek unggulan</label
          >
        </div>
      </div>
      <div class="col-12 d-flex flex-wrap gap-2">
        <button
          class="btn btn-accent"
          :disabled="saving"
        >
          {{ saving ? "Menyimpan..." : "Simpan proyek" }}</button
        ><button
          v-if="editingId"
          type="button"
          class="btn btn-outline-soft"
          @click="startCreate"
        >
          Batal edit
        </button>
      </div>
    </form>
    <p class="text-muted-custom small mt-3 mb-0">
      <i class="bi bi-info-circle me-1"></i>Versi awal menerima URL thumbnail.
      Upload langsung ke Supabase Storage akan ditambahkan pada tahap
      berikutnya.
    </p>
  </div>

  <div class="panel p-3 p-md-4">
    <div
      class="d-flex flex-wrap justify-content-between align-items-center gap-3 mb-3"
    >
      <h2 class="h5 fw-bold mb-0">
        Daftar proyek
        <span class="text-muted-custom">
          ({{ filteredRows.length }} / {{ rows.length }})
        </span>
      </h2>

      <div class="d-flex flex-wrap gap-2">
        <input
          v-model="search"
          class="form-control"
          style="max-width: 220px"
          placeholder="Cari proyek..."
        />

        <select
          v-model="statusFilter"
          class="form-select"
          style="max-width: 160px"
        >
          <option value="all">Semua status</option>
          <option value="published">Published</option>
          <option value="draft">Draft</option>
        </select>

        <select
          v-model="categoryFilter"
          class="form-select"
          style="max-width: 190px"
        >
          <option value="all">Semua kategori</option>
          <option
            v-for="category in categories"
            :key="category.id"
            :value="category.id"
          >
            {{ category.name }}
          </option>
        </select>
      </div>
    </div>

    <div
      v-if="loading"
      class="text-muted-custom py-4"
    >
      Memuat data proyek...
    </div>
    <div
      v-else-if="filteredRows.length === 0"
      class="text-muted-custom py-4"
    >
      Belum ada proyek yang cocok.
    </div>
    <div
      v-else
      class="table-responsive"
    >
      <table class="table table-dark-custom align-middle mb-0">
        <thead>
          <tr>
            <th>Proyek</th>
            <th>Kategori</th>
            <th>Status</th>
            <th>Unggulan</th>
            <th class="text-end">Aksi</th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="row in filteredRows"
            :key="row.id"
          >
            <td>
              <div class="d-flex align-items-center gap-3">
                <img
                  v-if="row.thumbnail_url"
                  :src="row.thumbnail_url"
                  :alt="row.title"
                  loading="lazy"
                  class="rounded-3"
                  style="width: 64px; height: 48px; object-fit: cover"
                />

                <div
                  v-else
                  class="rounded-3 d-flex align-items-center justify-content-center"
                  style="
                    width: 64px;
                    height: 48px;
                    background: var(--surface-2, #252a32);
                  "
                >
                  <i class="bi bi-image text-secondary"></i>
                </div>

                <div>
                  <div class="fw-semibold">{{ row.title }}</div>
                  <div class="text-muted-custom small">/{{ row.slug }}</div>
                </div>
              </div>
            </td>
            <td>{{ row.project_categories?.name || "—" }}</td>
            <td>
              <span
                :class="[
                  'badge rounded-pill',
                  row.status === 'published'
                    ? 'text-bg-success'
                    : 'text-bg-secondary',
                ]"
                >{{ row.status }}</span
              >
            </td>
            <td>{{ row.featured ? "Ya" : "—" }}</td>
            <td class="text-end text-nowrap">
              <button
                class="btn btn-sm btn-outline-soft me-1"
                @click="startEdit(row)"
              >
                Edit</button
              ><button
                class="btn btn-sm btn-outline-danger rounded-pill"
                @click="deleteProject(row)"
              >
                Hapus
              </button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>
