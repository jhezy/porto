<script setup>
import { computed, onMounted, onBeforeUnmount, ref } from "vue";
import { supabase } from "../../lib/supabase";
import { createPdfThumbnail } from "../../utils/pdfThumbnail";

const BUCKET = "certificates";
const MAX_FILE_SIZE = 10 * 1024 * 1024;

const certificates = ref([]);
const loading = ref(false);
const saving = ref(false);
const deletingId = ref(null);
const errorMessage = ref("");
const successMessage = ref("");
const search = ref("");
const showForm = ref(false);
const editingId = ref(null);
const selectedFile = ref(null);
const fileInput = ref(null);
const previewUrl = ref("");
const existingFileUrl = ref("");
const existingThumbnailUrl = ref("");

const emptyForm = () => ({
  title: "",
  issuer: "",
  credential_url: "",
  issued_at: "",
  sort_order: 0,
  is_visible: true,
});

const form = ref(emptyForm());

async function uploadCertificateFiles(file) {
  const isPdf = file.type === "application/pdf";

  // Gambar biasa dipakai langsung sebagai thumbnail.
  const thumbnailFile = isPdf ? await createPdfThumbnail(file) : file;

  const originalExtension = isPdf
    ? "pdf"
    : file.type === "image/jpeg"
      ? "jpg"
      : file.type === "image/png"
        ? "png"
        : "webp";

  const originalPath = `${crypto.randomUUID()}.${originalExtension}`;

  const thumbnailPath = isPdf ? `${crypto.randomUUID()}.webp` : originalPath;

  const storage = supabase.storage.from("certificates");
  const uploadedPaths = [];

  try {
    if (isPdf) {
      const { error } = await storage.upload(originalPath, file, {
        contentType: "application/pdf",
        upsert: false,
      });

      if (error) throw error;
      uploadedPaths.push(originalPath);
    }

    const { error: thumbnailError } = await storage.upload(
      thumbnailPath,
      thumbnailFile,
      {
        contentType: thumbnailFile.type,
        upsert: false,
      },
    );

    if (thumbnailError) throw thumbnailError;
    uploadedPaths.push(thumbnailPath);

    const { data: originalData } = storage.getPublicUrl(originalPath);

    const { data: thumbnailData } = storage.getPublicUrl(thumbnailPath);

    return {
      file_url: isPdf ? originalData.publicUrl : thumbnailData.publicUrl,
      image_url: thumbnailData.publicUrl,
      uploadedPaths,
    };
  } catch (error) {
    // Bersihkan upload yang berhasil jika proses berikutnya gagal.
    if (uploadedPaths.length) {
      await storage.remove(uploadedPaths);
    }

    throw error;
  }
}

const allowedTypes = [
  "image/jpeg",
  "image/png",
  "image/webp",
  "application/pdf",
];

const filteredCertificates = computed(() => {
  const keyword = search.value.trim().toLowerCase();

  if (!keyword) return certificates.value;

  return certificates.value.filter((item) =>
    [item.title, item.issuer]
      .filter(Boolean)
      .some((value) => value.toLowerCase().includes(keyword)),
  );
});

const visibleCount = computed(
  () => certificates.value.filter((item) => item.is_visible).length,
);

const isPdf = (url) => /\.pdf(?:$|[?#])/i.test(url || "");

const isImage = (url) => /\.(jpe?g|png|webp)(?:$|[?#])/i.test(url || "");

const formatDate = (value) => {
  if (!value) return "—";

  return new Date(`${value}T00:00:00`).toLocaleDateString("id-ID", {
    day: "numeric",
    month: "long",
    year: "numeric",
  });
};

const clearMessages = () => {
  errorMessage.value = "";
  successMessage.value = "";
};

const clearPreview = () => {
  if (previewUrl.value) {
    URL.revokeObjectURL(previewUrl.value);
  }

  previewUrl.value = "";
};

const resetForm = () => {
  clearPreview();
  form.value = emptyForm();
  selectedFile.value = null;
  existingFileUrl.value = "";
  existingThumbnailUrl.value = "";
  editingId.value = null;

  if (fileInput.value) {
    fileInput.value.value = "";
  }
};

const getStoragePath = (url) => {
  if (!url) return null;

  try {
    const parsed = new URL(url);
    const marker = `/storage/v1/object/public/${BUCKET}/`;
    const index = parsed.pathname.indexOf(marker);

    if (index === -1) return null;

    return decodeURIComponent(parsed.pathname.slice(index + marker.length));
  } catch {
    return null;
  }
};

const getPublicUrl = (path) => {
  const { data } = supabase.storage.from(BUCKET).getPublicUrl(path);
  return data.publicUrl;
};

const fetchCertificates = async () => {
  loading.value = true;
  errorMessage.value = "";

  try {
    const { data, error } = await supabase
      .from("certificates")
      .select(
        `
    id,
    title,
    issuer,
    credential_url,
    issued_at,
    image_url,
    file_url,
    sort_order,
    is_visible,
    created_at
  `,
      )
      .order("sort_order", { ascending: true })
      .order("created_at", { ascending: false });

    if (error) throw error;

    certificates.value = data || [];
  } catch (error) {
    errorMessage.value = error.message || "Gagal mengambil data sertifikat.";
  } finally {
    loading.value = false;
  }
};

const openCreateForm = () => {
  clearMessages();
  resetForm();
  showForm.value = true;
};

const openEditForm = (item) => {
  clearMessages();
  resetForm();

  editingId.value = item.id;
  existingThumbnailUrl.value = item.image_url || "";
  existingFileUrl.value = item.file_url || item.image_url || "";

  form.value = {
    title: item.title || "",
    issuer: item.issuer || "",
    credential_url: item.credential_url || "",
    issued_at: item.issued_at || "",
    sort_order: item.sort_order ?? 0,
    is_visible: item.is_visible ?? true,
  };

  showForm.value = true;
};

const closeForm = () => {
  if (saving.value) return;

  showForm.value = false;
  resetForm();
};

const onFileChange = (event) => {
  clearMessages();
  clearPreview();

  const file = event.target.files?.[0];

  if (!file) {
    selectedFile.value = null;
    return;
  }

  if (!allowedTypes.includes(file.type)) {
    errorMessage.value = "Format file harus JPG, PNG, WebP, atau PDF.";
    event.target.value = "";
    selectedFile.value = null;
    return;
  }

  if (file.size > MAX_FILE_SIZE) {
    errorMessage.value = "Ukuran file maksimal 10 MB.";
    event.target.value = "";
    selectedFile.value = null;
    return;
  }

  selectedFile.value = file;
  previewUrl.value = URL.createObjectURL(file);
};

const uploadFile = async (file) => {
  const extensionByType = {
    "image/jpeg": "jpg",
    "image/png": "png",
    "image/webp": "webp",
    "application/pdf": "pdf",
  };

  const extension = extensionByType[file.type];

  if (!extension) {
    throw new Error("Format file tidak didukung.");
  }

  const path = `${crypto.randomUUID()}.${extension}`;

  const { error } = await supabase.storage.from(BUCKET).upload(path, file, {
    contentType: file.type,
    cacheControl: "3600",
    upsert: false,
  });

  if (error) throw error;

  return {
    path,
    url: getPublicUrl(path),
  };
};

const removeStorageFile = async (url) => {
  const path = getStoragePath(url);

  // Jangan menghapus URL eksternal atau URL yang tidak berasal
  // dari bucket certificates milik project ini.
  if (!path) return;

  const { error } = await supabase.storage.from(BUCKET).remove([path]);

  if (error) {
    console.error("Gagal menghapus file Storage:", error.message);
    throw error;
  }
};

const saveCertificate = async () => {
  clearMessages();

  if (!form.value.title.trim()) {
    errorMessage.value = "Judul sertifikat wajib diisi.";
    return;
  }

  const sortOrder = Number(form.value.sort_order);

  if (!Number.isInteger(sortOrder) || sortOrder < 0) {
    errorMessage.value = "Urutan harus berupa bilangan bulat minimal 0.";
    return;
  }

  if (!editingId.value && !selectedFile.value) {
    errorMessage.value = "Pilih file sertifikat terlebih dahulu.";
    return;
  }

  if (
    form.value.credential_url &&
    !/^https?:\/\/\S+$/i.test(form.value.credential_url.trim())
  ) {
    errorMessage.value = "URL kredensial harus menggunakan HTTP atau HTTPS.";
    return;
  }

  saving.value = true;

  let uploadedPaths = [];
  let databaseSaved = false;

  try {
    let imageUrl = existingThumbnailUrl.value;
    let fileUrl = existingFileUrl.value;

    // Upload hanya jika pengguna memilih file baru.
    if (selectedFile.value) {
      const uploaded = await uploadCertificateFiles(selectedFile.value);

      imageUrl = uploaded.image_url;
      fileUrl = uploaded.file_url;
      uploadedPaths = uploaded.uploadedPaths;
    }

    const payload = {
      title: form.value.title.trim(),
      issuer: form.value.issuer.trim() || null,
      credential_url: form.value.credential_url.trim() || null,
      issued_at: form.value.issued_at || null,
      image_url: imageUrl || null,
      file_url: fileUrl || imageUrl || null,
      sort_order: sortOrder,
      is_visible: Boolean(form.value.is_visible),
    };

    let result;

    if (editingId.value) {
      result = await supabase
        .from("certificates")
        .update(payload)
        .eq("id", editingId.value);
    } else {
      result = await supabase.from("certificates").insert({
        id: crypto.randomUUID(),
        ...payload,
        created_at: new Date().toISOString(),
      });
    }

    if (result.error) throw result.error;

    databaseSaved = true;

    // Hapus file lama setelah database berhasil diperbarui.
    if (selectedFile.value && editingId.value) {
      const oldPaths = [
        getStoragePath(existingFileUrl.value),
        getStoragePath(existingThumbnailUrl.value),
      ].filter(Boolean);

      const uniqueOldPaths = [...new Set(oldPaths)];

      if (uniqueOldPaths.length) {
        const { error: removeError } = await supabase.storage
          .from(BUCKET)
          .remove(uniqueOldPaths);

        if (removeError) {
          console.error("File lama gagal dihapus:", removeError.message);

          successMessage.value =
            "Sertifikat tersimpan, tetapi file lama gagal dihapus dari Storage.";
        }
      }
    }

    if (!successMessage.value) {
      successMessage.value = editingId.value
        ? "Sertifikat berhasil diperbarui."
        : "Sertifikat berhasil ditambahkan.";
    }

    showForm.value = false;
    resetForm();

    await fetchCertificates();
  } catch (error) {
    // Jika database gagal, hapus file baru yang telanjur di-upload.
    if (!databaseSaved && uploadedPaths.length) {
      const { error: cleanupError } = await supabase.storage
        .from(BUCKET)
        .remove(uploadedPaths);

      if (cleanupError) {
        console.error("Pembersihan upload gagal:", cleanupError.message);
      }
    }

    errorMessage.value = error.message || "Gagal menyimpan sertifikat.";
  } finally {
    saving.value = false;
  }
};

const deleteCertificate = async (item) => {
  const confirmed = window.confirm(
    `Hapus sertifikat "${item.title}" beserta file dan thumbnail-nya?`,
  );

  if (!confirmed) return;

  clearMessages();
  deletingId.value = item.id;

  try {
    const { error } = await supabase
      .from("certificates")
      .delete()
      .eq("id", item.id);

    if (error) throw error;

    const paths = [
      getStoragePath(item.file_url || item.image_url),
      getStoragePath(item.image_url),
    ].filter(Boolean);

    const uniquePaths = [...new Set(paths)];

    if (uniquePaths.length) {
      const { error: storageError } = await supabase.storage
        .from(BUCKET)
        .remove(uniquePaths);

      if (storageError) {
        successMessage.value =
          "Data sertifikat dihapus, tetapi sebagian file Storage gagal dihapus.";
      } else {
        successMessage.value =
          "Sertifikat, file asli, dan thumbnail berhasil dihapus.";
      }
    } else {
      successMessage.value = "Data sertifikat berhasil dihapus.";
    }

    await fetchCertificates();
  } catch (error) {
    errorMessage.value = error.message || "Gagal menghapus sertifikat.";
  } finally {
    deletingId.value = null;
  }
};

const toggleVisibility = async (item) => {
  clearMessages();

  const nextValue = !item.is_visible;

  const { error } = await supabase
    .from("certificates")
    .update({ is_visible: nextValue })
    .eq("id", item.id);

  if (error) {
    errorMessage.value = error.message;
    return;
  }

  item.is_visible = nextValue;
  successMessage.value = nextValue
    ? "Sertifikat ditampilkan di portofolio."
    : "Sertifikat disembunyikan.";
};

onMounted(fetchCertificates);

onBeforeUnmount(() => {
  clearPreview();
});
</script>

<template>
  <div class="certificates-page">
    <div class="page-header">
      <div>
        <div class="eyebrow">
          <i class="bi bi-award"></i>
          PORTOFOLIO MANAGEMENT
        </div>

        <h1>Kelola Sertifikat</h1>
        <p>Upload dan kelola sertifikat pencapaianmu.</p>
      </div>

      <button
        class="btn-primary-custom"
        @click="openCreateForm"
      >
        <i class="bi bi-cloud-upload"></i>
        Upload Sertifikat
      </button>
    </div>

    <div class="stats-grid">
      <div class="stat-card">
        <div class="stat-icon">
          <i class="bi bi-award"></i>
        </div>
        <div>
          <span>Total sertifikat</span>
          <strong>{{ certificates.length }}</strong>
        </div>
      </div>

      <div class="stat-card">
        <div class="stat-icon">
          <i class="bi bi-eye"></i>
        </div>
        <div>
          <span>Ditampilkan</span>
          <strong>{{ visibleCount }}</strong>
        </div>
      </div>

      <div class="stat-card">
        <div class="stat-icon">
          <i class="bi bi-eye-slash"></i>
        </div>
        <div>
          <span>Disembunyikan</span>
          <strong>{{ certificates.length - visibleCount }}</strong>
        </div>
      </div>
    </div>

    <div
      v-if="errorMessage"
      class="alert-custom alert-error"
      role="alert"
    >
      <i class="bi bi-exclamation-circle"></i>
      <span>{{ errorMessage }}</span>
      <button
        @click="errorMessage = ''"
        aria-label="Tutup pesan"
      >
        ×
      </button>
    </div>

    <div
      v-if="successMessage"
      class="alert-custom alert-success"
      role="status"
    >
      <i class="bi bi-check-circle"></i>
      <span>{{ successMessage }}</span>
      <button
        @click="successMessage = ''"
        aria-label="Tutup pesan"
      >
        ×
      </button>
    </div>

    <section class="content-card">
      <div class="toolbar">
        <div>
          <h2>Daftar Sertifikat</h2>
          <p>File gambar dan PDF yang tersimpan di Supabase Storage.</p>
        </div>

        <div class="search-box">
          <i class="bi bi-search"></i>
          <input
            v-model="search"
            type="search"
            placeholder="Cari sertifikat..."
            aria-label="Cari sertifikat"
          />
        </div>
      </div>

      <div
        v-if="loading"
        class="state-message"
      >
        <span class="spinner-border spinner-border-sm"></span>
        Memuat sertifikat...
      </div>

      <div
        v-else-if="filteredCertificates.length === 0"
        class="state-message empty-state"
      >
        <i class="bi bi-file-earmark-medical"></i>
        <strong>Belum ada sertifikat</strong>
        <span>Upload sertifikat pertama untuk portofoliomu.</span>
        <button
          class="btn-primary-custom"
          @click="openCreateForm"
        >
          <i class="bi bi-cloud-upload"></i>
          Upload sekarang
        </button>
      </div>

      <div
        v-else
        class="table-responsive"
      >
        <table class="certificates-table">
          <thead>
            <tr>
              <th>File</th>
              <th>Informasi</th>
              <th>Urutan</th>
              <th>Status</th>
              <th class="text-end">Aksi</th>
            </tr>
          </thead>

          <tbody>
            <tr
              v-for="item in filteredCertificates"
              :key="item.id"
            >
              <td>
                <a
                  class="file-preview"
                  :href="item.image_url"
                  target="_blank"
                  rel="noopener noreferrer"
                  :title="`Buka file ${item.title}`"
                >
                  <template v-if="isPdf(item.image_url)">
                    <span class="pdf-thumbnail">
                      <i class="bi bi-file-earmark-pdf"></i>
                      <small>PDF</small>
                    </span>
                  </template>
                  <img
                    v-else
                    :src="item.image_url"
                    :alt="item.title"
                    loading="lazy"
                  />
                </a>
              </td>

              <td>
                <div class="certificate-info">
                  <strong>{{ item.title }}</strong>
                  <span>{{ item.issuer || "Penerbit tidak dicantumkan" }}</span>
                  <small>{{ formatDate(item.issued_at) }}</small>
                </div>
              </td>

              <td>
                <span class="order-badge">{{ item.sort_order }}</span>
              </td>

              <td>
                <span
                  class="status-badge"
                  :class="item.is_visible ? 'status-visible' : 'status-hidden'"
                >
                  <i
                    :class="item.is_visible ? 'bi bi-eye' : 'bi bi-eye-slash'"
                  ></i>
                  {{ item.is_visible ? "Publik" : "Tersembunyi" }}
                </span>
              </td>

              <td>
                <div class="actions">
                  <button
                    class="icon-button"
                    :title="item.is_visible ? 'Sembunyikan' : 'Tampilkan'"
                    :aria-label="item.is_visible ? 'Sembunyikan' : 'Tampilkan'"
                    @click="toggleVisibility(item)"
                  >
                    <i
                      :class="item.is_visible ? 'bi bi-eye-slash' : 'bi bi-eye'"
                    ></i>
                  </button>

                  <button
                    class="icon-button"
                    title="Edit sertifikat"
                    aria-label="Edit sertifikat"
                    @click="openEditForm(item)"
                  >
                    <i class="bi bi-pencil-square"></i>
                  </button>

                  <button
                    class="icon-button danger"
                    title="Hapus sertifikat"
                    aria-label="Hapus sertifikat"
                    :disabled="deletingId === item.id"
                    @click="deleteCertificate(item)"
                  >
                    <span
                      v-if="deletingId === item.id"
                      class="spinner-border spinner-border-sm"
                    ></span>
                    <i
                      v-else
                      class="bi bi-trash3"
                    ></i>
                  </button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>

    <Teleport to="body">
      <div
        v-if="showForm"
        class="modal-backdrop-custom"
        @click.self="closeForm"
      >
        <section
          class="certificate-modal"
          role="dialog"
          aria-modal="true"
          aria-labelledby="certificate-modal-title"
        >
          <div class="modal-header-custom">
            <div>
              <div class="eyebrow">
                <i class="bi bi-cloud-arrow-up"></i>
                CERTIFICATE
              </div>
              <h2 id="certificate-modal-title">
                {{ editingId ? "Edit Sertifikat" : "Upload Sertifikat" }}
              </h2>
              <p>Lengkapi informasi dan pilih file sertifikat.</p>
            </div>

            <button
              class="icon-button"
              :disabled="saving"
              @click="closeForm"
              aria-label="Tutup formulir"
            >
              <i class="bi bi-x-lg"></i>
            </button>
          </div>

          <form
            class="certificate-form"
            @submit.prevent="saveCertificate"
          >
            <div class="form-field">
              <label for="certificate-title">
                Judul sertifikat <span>*</span>
              </label>
              <input
                id="certificate-title"
                v-model="form.title"
                type="text"
                maxlength="255"
                placeholder="Contoh: Full Stack Web Development"
                required
              />
            </div>

            <div class="form-field">
              <label for="certificate-issuer">Penerbit / penyelenggara</label>
              <input
                id="certificate-issuer"
                v-model="form.issuer"
                type="text"
                placeholder="Contoh: Dicoding Indonesia"
              />
            </div>

            <div class="form-field">
              <label for="certificate-file">
                File sertifikat
                <span v-if="!editingId">*</span>
              </label>

              <label
                class="upload-dropzone"
                for="certificate-file"
                :class="{ 'has-file': selectedFile || existingFileUrl }"
              >
                <input
                  id="certificate-file"
                  ref="fileInput"
                  type="file"
                  accept=".jpg,.jpeg,.png,.webp,.pdf,image/jpeg,image/png,image/webp,application/pdf"
                  @change="onFileChange"
                />

                <template v-if="previewUrl">
                  <img
                    v-if="selectedFile?.type.startsWith('image/')"
                    :src="previewUrl"
                    class="upload-image-preview"
                    alt="Preview file sertifikat"
                  />

                  <div
                    v-else
                    class="upload-pdf-preview"
                  >
                    <i class="bi bi-file-earmark-pdf"></i>
                    <strong>Preview dokumen PDF</strong>
                    <span>{{ selectedFile?.name }}</span>
                    <a
                      :href="previewUrl"
                      target="_blank"
                      rel="noopener noreferrer"
                      @click.stop
                    >
                      Buka preview PDF
                    </a>
                  </div>
                </template>

                <template v-else-if="existingFileUrl">
                  <img
                    v-if="existingThumbnailUrl"
                    :src="existingThumbnailUrl"
                    class="upload-image-preview"
                    alt="Thumbnail sertifikat saat ini"
                  />

                  <div
                    v-else
                    class="upload-pdf-preview"
                  >
                    <i class="bi bi-file-earmark-pdf"></i>
                    <strong>File sertifikat saat ini</strong>
                  </div>

                  <a
                    :href="existingFileUrl"
                    target="_blank"
                    rel="noopener noreferrer"
                    @click.stop
                  >
                    Buka file asli
                  </a>

                  <span class="replace-hint">
                    Klik area upload untuk mengganti file
                  </span>
                </template>

                <template v-else>
                  <span class="upload-icon">
                    <i class="bi bi-cloud-arrow-up"></i>
                  </span>
                  <strong>Pilih file sertifikat</strong>
                  <span>JPG, PNG, WebP, atau PDF</span>
                  <small>Maksimal 10 MB</small>
                </template>
              </label>

              <p class="field-help">
                File disimpan di Supabase Storage. Jika mengedit tanpa memilih
                file baru, file lama akan tetap digunakan.
              </p>
            </div>

            <div class="form-field">
              <label for="certificate-credential-url">
                URL verifikasi sertifikat
              </label>
              <input
                id="certificate-credential-url"
                v-model="form.credential_url"
                type="url"
                placeholder="https://..."
              />
            </div>

            <div class="form-row">
              <div class="form-field">
                <label for="certificate-issued-at">Tanggal terbit</label>
                <input
                  id="certificate-issued-at"
                  v-model="form.issued_at"
                  type="date"
                />
              </div>

              <div class="form-field">
                <label for="certificate-order">Urutan tampilan</label>
                <input
                  id="certificate-order"
                  v-model.number="form.sort_order"
                  type="number"
                  min="0"
                  step="1"
                  required
                />
              </div>
            </div>

            <label class="visibility-toggle">
              <input
                v-model="form.is_visible"
                type="checkbox"
              />
              <span class="toggle-track"></span>
              <span>
                <strong>Tampilkan di portofolio</strong>
                <small>Sertifikat dapat dilihat pengunjung publik.</small>
              </span>
            </label>

            <div class="modal-footer-custom">
              <button
                type="button"
                class="btn-secondary-custom"
                :disabled="saving"
                @click="closeForm"
              >
                Batal
              </button>

              <button
                type="submit"
                class="btn-primary-custom"
                :disabled="saving"
              >
                <span
                  v-if="saving"
                  class="spinner-border spinner-border-sm"
                ></span>
                <i
                  v-else
                  class="bi bi-cloud-check"
                ></i>
                {{
                  saving
                    ? "Menyimpan..."
                    : editingId
                      ? "Simpan Perubahan"
                      : "Upload & Simpan"
                }}
              </button>
            </div>
          </form>
        </section>
      </div>
    </Teleport>
  </div>
</template>

<style scoped>
.certificates-page {
  --accent: #5eead4;
  --accent-dark: #0f766e;
  --surface: #111c27;
  --surface-raised: #172532;
  --border: rgba(148, 163, 184, 0.16);
  --muted: #94a3b8;
  color: #e5edf5;
  padding: 8px 0 32px;
}

.page-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 20px;
  margin-bottom: 26px;
}

.eyebrow {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 9px;
  color: var(--accent);
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 1.6px;
}

.page-header h1 {
  margin: 0 0 8px;
  color: #f8fafc;
  font-size: clamp(24px, 3vw, 32px);
  font-weight: 750;
  letter-spacing: -0.8px;
}

.page-header p,
.toolbar p,
.modal-header-custom p {
  margin: 0;
  color: var(--muted);
  font-size: 13px;
}

.btn-primary-custom,
.btn-secondary-custom {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 9px;
  min-height: 42px;
  padding: 10px 16px;
  border: 1px solid transparent;
  border-radius: 10px;
  font-size: 13px;
  font-weight: 700;
  cursor: pointer;
  transition: 0.2s ease;
}

.btn-primary-custom {
  background: var(--accent);
  color: #092b2a;
}

.btn-primary-custom:hover:not(:disabled) {
  background: #99f6e4;
  transform: translateY(-1px);
}

.btn-secondary-custom {
  background: var(--surface-raised);
  border-color: var(--border);
  color: #dbe5ef;
}

button:disabled {
  opacity: 0.55;
  cursor: not-allowed;
}

.stats-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 16px;
  margin-bottom: 22px;
}

.stat-card {
  display: flex;
  align-items: center;
  gap: 14px;
  padding: 20px;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 14px;
}

.stat-icon {
  display: grid;
  place-items: center;
  flex-shrink: 0;
  width: 44px;
  height: 44px;
  border-radius: 12px;
  background: rgba(94, 234, 212, 0.1);
  color: var(--accent);
  font-size: 20px;
}

.stat-card span,
.stat-card strong {
  display: block;
}

.stat-card span {
  margin-bottom: 5px;
  color: var(--muted);
  font-size: 12px;
}

.stat-card strong {
  color: #f8fafc;
  font-size: 25px;
  line-height: 1;
}

.content-card {
  overflow: hidden;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 15px;
}

.toolbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 20px;
  padding: 22px;
  border-bottom: 1px solid var(--border);
}

.toolbar h2,
.modal-header-custom h2 {
  margin: 0 0 7px;
  color: #f8fafc;
  font-size: 18px;
  font-weight: 750;
}

.search-box {
  display: flex;
  align-items: center;
  gap: 9px;
  width: min(260px, 100%);
  padding: 0 12px;
  background: #0b1520;
  border: 1px solid var(--border);
  border-radius: 9px;
  color: var(--muted);
}

.search-box input {
  width: 100%;
  min-width: 0;
  height: 40px;
  border: 0;
  outline: none;
  background: transparent;
  color: #e5edf5;
  font-size: 12px;
}

.table-responsive {
  overflow-x: auto;
}

.certificates-table {
  width: 100%;
  border-collapse: collapse;
  white-space: nowrap;
}

.certificates-table th {
  padding: 14px 20px;
  background: rgba(255, 255, 255, 0.015);
  color: #91a4b8;
  font-size: 10px;
  font-weight: 800;
  letter-spacing: 0.9px;
  text-align: left;
  text-transform: uppercase;
}

.certificates-table td {
  padding: 15px 20px;
  border-top: 1px solid var(--border);
  vertical-align: middle;
}

.certificates-table tbody tr:hover {
  background: rgba(255, 255, 255, 0.018);
}

.file-preview {
  display: grid;
  place-items: center;
  width: 76px;
  height: 56px;
  overflow: hidden;
  border: 1px solid var(--border);
  border-radius: 8px;
  background: #0b1520;
}

.file-preview img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.pdf-thumbnail {
  display: flex;
  align-items: center;
  flex-direction: column;
  gap: 2px;
  color: #fda4af;
}

.pdf-thumbnail i {
  font-size: 23px;
}

.pdf-thumbnail small {
  font-size: 9px;
  font-weight: 800;
}

.certificate-info {
  display: flex;
  flex-direction: column;
  gap: 5px;
  max-width: 330px;
  white-space: normal;
}

.certificate-info strong {
  color: #eaf2f9;
  font-size: 13px;
  font-weight: 700;
}

.certificate-info span,
.certificate-info small {
  color: var(--muted);
  font-size: 11px;
}

.order-badge {
  display: inline-flex;
  justify-content: center;
  min-width: 30px;
  padding: 5px 8px;
  border-radius: 7px;
  background: var(--surface-raised);
  color: #dbe5ef;
  font-size: 12px;
}

.status-badge {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 6px 9px;
  border-radius: 7px;
  font-size: 11px;
  font-weight: 650;
}

.status-visible {
  background: rgba(94, 234, 212, 0.1);
  color: var(--accent);
}

.status-hidden {
  background: rgba(148, 163, 184, 0.1);
  color: #aab8c8;
}

.actions {
  display: flex;
  justify-content: flex-end;
  gap: 6px;
}

.icon-button {
  display: inline-grid;
  place-items: center;
  width: 34px;
  height: 34px;
  border: 1px solid var(--border);
  border-radius: 8px;
  background: var(--surface-raised);
  color: #cbd5e1;
  cursor: pointer;
  transition: 0.2s ease;
}

.icon-button:hover:not(:disabled) {
  border-color: rgba(94, 234, 212, 0.45);
  color: var(--accent);
}

.icon-button.danger:hover:not(:disabled) {
  border-color: rgba(248, 113, 113, 0.4);
  color: #fca5a5;
}

.text-end {
  text-align: right !important;
}

.state-message {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 10px;
  padding: 48px 20px;
  color: var(--muted);
  font-size: 13px;
}

.empty-state {
  flex-direction: column;
  gap: 12px;
}

.empty-state > i {
  color: var(--accent);
  font-size: 38px;
}

.empty-state strong {
  color: #eaf2f9;
}

.empty-state .btn-primary-custom {
  margin-top: 6px;
}

.alert-custom {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-bottom: 16px;
  padding: 12px 14px;
  border: 1px solid var(--border);
  border-radius: 10px;
  font-size: 12px;
}

.alert-custom span {
  flex: 1;
}

.alert-custom button {
  border: 0;
  background: transparent;
  color: inherit;
  font-size: 20px;
}

.alert-error {
  background: rgba(127, 29, 29, 0.18);
  color: #fca5a5;
}

.alert-success {
  background: rgba(15, 118, 110, 0.15);
  color: var(--accent);
}

.modal-backdrop-custom {
  position: fixed;
  z-index: 2000;
  inset: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  overflow-y: auto;
  padding: 24px 12px;
  background: rgba(2, 6, 23, 0.8);
  backdrop-filter: blur(7px);
}

.certificate-modal {
  width: min(100%, 620px);
  max-height: calc(100vh - 48px);
  overflow-y: auto;
  border: 1px solid rgba(148, 163, 184, 0.2);
  border-radius: 16px;
  background: #101b26;
  box-shadow: 0 24px 80px rgba(0, 0, 0, 0.35);
}

.modal-header-custom {
  display: flex;
  justify-content: space-between;
  gap: 20px;
  padding: 24px 26px 20px;
  border-bottom: 1px solid var(--border);
}

.certificate-form {
  display: flex;
  flex-direction: column;
  gap: 18px;
  padding: 24px 26px;
}

.form-field {
  display: flex;
  flex: 1;
  flex-direction: column;
  gap: 8px;
  min-width: 0;
}

.form-field > label {
  color: #dbe5ef;
  font-size: 12px;
  font-weight: 650;
}

.form-field > label > span {
  color: #fda4af;
}

.form-field > input {
  width: 100%;
  min-width: 0;
  min-height: 42px;
  padding: 10px 12px;
  border: 1px solid rgba(148, 163, 184, 0.2);
  border-radius: 9px;
  outline: none;
  background: #0b1520;
  color: #e5edf5;
  font-size: 12px;
  color-scheme: dark;
}

.form-field > input:focus {
  border-color: rgba(94, 234, 212, 0.7);
  box-shadow: 0 0 0 3px rgba(94, 234, 212, 0.08);
}

.form-field > input::placeholder {
  color: #64748b;
}

.upload-dropzone {
  display: flex;
  align-items: center;
  flex-direction: column;
  justify-content: center;
  gap: 9px;
  min-height: 175px;
  padding: 18px;
  overflow: hidden;
  border: 1px dashed rgba(94, 234, 212, 0.38);
  border-radius: 12px;
  background: rgba(94, 234, 212, 0.035);
  text-align: center;
  cursor: pointer;
}

.upload-dropzone > input[type="file"] {
  display: none;
}

.upload-dropzone > strong {
  color: #e5edf5;
  font-size: 13px;
}

.upload-dropzone > span:not(.upload-icon):not(.replace-hint) {
  color: var(--muted);
  font-size: 11px;
}

.upload-dropzone > small {
  color: #71849a;
  font-size: 10px;
}

.upload-icon {
  display: grid;
  place-items: center;
  width: 44px;
  height: 44px;
  border-radius: 12px;
  background: rgba(94, 234, 212, 0.1);
  color: var(--accent);
  font-size: 23px;
}

.upload-image-preview {
  display: block;
  width: auto;
  max-width: 100%;
  max-height: 230px;
  object-fit: contain;
  border-radius: 7px;
}

.upload-pdf-preview {
  display: flex;
  align-items: center;
  flex-direction: column;
  gap: 8px;
  color: var(--muted);
  font-size: 11px;
}

.upload-pdf-preview > i {
  color: #fda4af;
  font-size: 38px;
}

.upload-pdf-preview strong {
  color: #e5edf5;
  font-size: 13px;
}

.upload-pdf-preview a {
  color: var(--accent);
  text-decoration: none;
}

.replace-hint {
  color: var(--accent);
  font-size: 11px;
}

.field-help {
  margin: 0;
  color: #8495a8;
  font-size: 11px;
  line-height: 1.6;
}

.form-row {
  display: flex;
  gap: 14px;
}

.visibility-toggle {
  display: flex;
  align-items: center;
  gap: 12px;
  cursor: pointer;
}

.visibility-toggle > input {
  position: absolute;
  width: 1px;
  height: 1px;
  opacity: 0;
}

.toggle-track {
  position: relative;
  flex-shrink: 0;
  width: 38px;
  height: 22px;
  border-radius: 20px;
  background: #334155;
  transition: 0.2s ease;
}

.toggle-track::after {
  position: absolute;
  top: 3px;
  left: 3px;
  width: 16px;
  height: 16px;
  border-radius: 50%;
  background: white;
  content: "";
  transition: 0.2s ease;
}

.visibility-toggle > input:checked + .toggle-track {
  background: #0f766e;
}

.visibility-toggle > input:checked + .toggle-track::after {
  left: 19px;
  background: #99f6e4;
}

.visibility-toggle strong,
.visibility-toggle small {
  display: block;
}

.visibility-toggle strong {
  margin-bottom: 4px;
  color: #e5edf5;
  font-size: 12px;
}

.visibility-toggle small {
  color: var(--muted);
  font-size: 11px;
}

.modal-footer-custom {
  display: flex;
  justify-content: flex-end;
  gap: 10px;
  padding-top: 18px;
  border-top: 1px solid var(--border);
}

@media (max-width: 768px) {
  .page-header {
    align-items: flex-start;
    flex-direction: column;
  }

  .stats-grid {
    grid-template-columns: 1fr;
    gap: 10px;
  }

  .stat-card {
    padding: 15px;
  }

  .toolbar {
    align-items: stretch;
    flex-direction: column;
    padding: 18px;
  }

  .search-box {
    width: 100%;
  }

  .certificates-table th,
  .certificates-table td {
    padding: 12px;
  }

  .certificate-form,
  .modal-header-custom {
    padding: 20px;
  }
}

@media (max-width: 480px) {
  .form-row {
    flex-direction: column;
  }

  .modal-backdrop-custom {
    align-items: flex-start;
    padding: 10px;
  }

  .certificate-modal {
    max-height: calc(100vh - 20px);
  }

  .modal-footer-custom {
    flex-direction: column-reverse;
  }

  .modal-footer-custom button {
    width: 100%;
  }
}
</style>
